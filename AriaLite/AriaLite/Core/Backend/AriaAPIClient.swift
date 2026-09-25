//
//  AriaAPIClient.swift
//  AriaLite
//
//  Client HTTP verso aria-backend: header comuni, retry su 401,
//  richieste JSON e stream SSE di POST /v1/responses.
//

import Foundation

/// Azienda, stabilimento e lingua attivi: finiscono negli header e nei body.
actor AriaContext {
    nonisolated struct Snapshot: Sendable {
        let companyId: String?
        let plantId: String?
        let locale: String
    }

    private(set) var companyId: String? = UserDefaults.standard.string(forKey: "aria.company_id")
    private(set) var plantId: String? = UserDefaults.standard.string(forKey: "aria.plant_id")

    /// Lingua dell'app: il backend la usa per fissare la lingua della sessione al primo turno.
    nonisolated var locale: String {
        Locale.current.language.languageCode?.identifier == "it" ? "it" : "en"
    }

    func setCompany(_ id: String?) {
        companyId = id
        UserDefaults.standard.set(id, forKey: "aria.company_id")
    }

    func setPlant(_ id: String?) {
        plantId = id
        UserDefaults.standard.set(id, forKey: "aria.plant_id")
    }

    func snapshot() -> Snapshot { Snapshot(companyId: companyId, plantId: plantId, locale: locale) }
}

/// Rete e decodifica JSON girano fuori dal main thread (`@concurrent`).
nonisolated final class AriaAPIClient: Sendable {
    let config: AriaConfig
    let auth: AriaAuth
    let context: AriaContext
    private let session: URLSession
    private let streamSession: URLSession

    init(config: AriaConfig, auth: AriaAuth, context: AriaContext) {
        self.config = config
        self.auth = auth
        self.context = context
        session = .shared
        let streaming = URLSessionConfiguration.default
        streaming.timeoutIntervalForRequest = config.streamIdleTimeout
        streaming.timeoutIntervalForResource = 30 * 60
        streamSession = URLSession(configuration: streaming)
    }

    // MARK: JSON

    @concurrent
    func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let raw = try await data("GET", path, query: query)
        do { return try JSONDecoder().decode(T.self, from: raw) }
        catch { throw AriaError.decoding("\(T.self): \(error)") }
    }

    /// POST / PATCH con body JSON; la risposta si decodifica in `T`.
    @concurrent
    func send<T: Decodable & Sendable>(_ method: String, _ path: String,
                                       body: some Encodable & Sendable) async throws -> T {
        let raw = try await data(method, path, body: try JSONEncoder().encode(body))
        do { return try JSONDecoder().decode(T.self, from: raw) }
        catch { throw AriaError.decoding("\(T.self): \(error)") }
    }

    /// Come `send`, quando la risposta non serve (204 o un oggetto qualsiasi).
    @concurrent
    func perform(_ method: String, _ path: String, body: some Encodable & Sendable) async throws {
        _ = try await data(method, path, body: try JSONEncoder().encode(body))
    }

    @concurrent
    func perform(_ method: String, _ path: String) async throws {
        _ = try await data(method, path)
    }

    /// Richiesta con un solo retry su 401 (token rinnovato nel frattempo).
    @concurrent
    func data(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> Data {
        var retried = false
        while true {
            let req = try await request(method, path, query: query, body: body)
            let (data, response) = try await session.data(for: req)
            if (response as? HTTPURLResponse)?.statusCode == 401, !retried {
                retried = true
                await auth.invalidate()
                continue
            }
            try AriaHTTP.check(response, data)
            return data
        }
    }

    // MARK: SSE

    /// Apre POST /v1/responses e restituisce gli eventi già interpretati man mano che arrivano.
    /// Cancellare il Task che consuma lo stream chiude la connessione.
    func stream(_ payload: AriaResponsesRequest) -> AsyncThrowingStream<AriaStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task(name: "aria.responses.stream") {
                do {
                    let body = try JSONEncoder().encode(payload)
                    var retried = false
                    while true {
                        let req = try await self.request("POST", "v1/responses", body: body,
                                                         accept: "text/event-stream")
                        let (bytes, response) = try await self.streamSession.bytes(for: req)
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        if status == 401, !retried {
                            retried = true
                            await self.auth.invalidate()
                            continue
                        }
                        if !(200..<300).contains(status) {
                            var errorBody = Data()
                            for try await byte in bytes {
                                errorBody.append(byte)
                                if errorBody.count >= 16_384 { break }
                            }
                            try AriaHTTP.check(response, errorBody)
                        }
                        var parser = AriaSSEParser()
                        AriaStreamTrace.event("open", "status", bytes: status)
                        for try await byte in bytes {
                            if let event = parser.consume(byte) {
                                AriaStreamTrace.event("recv", event.event, bytes: event.data.utf8.count)
                                continuation.yield(AriaStreamEvent(event))
                            }
                        }
                        if let event = parser.finish() { continuation.yield(AriaStreamEvent(event)) }
                        break
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Private

    private func request(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
                         accept: String = "application/json") async throws -> URLRequest {
        if let body, body.count > config.maxBodyBytes {
            throw AriaError.bodyTooLarge(bytes: body.count, limit: config.maxBodyBytes)
        }
        var url = config.apiBaseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        let token = try await auth.validAccessToken()
        let ctx = await context.snapshot()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(ctx.locale, forHTTPHeaderField: "Accept-Language")
        if let companyId = ctx.companyId { req.setValue(companyId, forHTTPHeaderField: "Company-Id") }
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        req.setValue(accept, forHTTPHeaderField: "Accept")
        if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return req
    }
}

// MARK: - SSE

nonisolated struct AriaSSEEvent: Sendable {
    let event: String
    let data: String
}

/// Parser incrementale: frame separati da una riga vuota, righe `event:` e `data:`.
nonisolated struct AriaSSEParser {
    private var buffer: [UInt8] = []

    mutating func consume(_ byte: UInt8) -> AriaSSEEvent? {
        if byte == 0x0D { return nil }  // normalizza \r\n
        buffer.append(byte)
        let n = buffer.count
        guard byte == 0x0A, n >= 2, buffer[n - 2] == 0x0A else { return nil }
        defer { buffer.removeAll(keepingCapacity: true) }
        return Self.parse(buffer)
    }

    mutating func finish() -> AriaSSEEvent? {
        defer { buffer.removeAll() }
        return buffer.isEmpty ? nil : Self.parse(buffer)
    }

    private static func parse(_ bytes: [UInt8]) -> AriaSSEEvent? {
        let text = String(decoding: bytes, as: UTF8.self)
        var event = "message"
        var dataLines: [String] = []
        for line in text.split(separator: "\n") {
            if line.hasPrefix(":") { continue }  // commento / keep-alive
            if line.hasPrefix("event:") {
                event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                var value = line.dropFirst(5)
                if value.first == " " { value = value.dropFirst() }
                dataLines.append(String(value))
            }
        }
        guard !dataLines.isEmpty else { return nil }
        return AriaSSEEvent(event: event, data: dataLines.joined(separator: "\n"))
    }
}
