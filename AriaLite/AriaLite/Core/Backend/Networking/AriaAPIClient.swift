//
//  AriaAPIClient.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
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
        // Mai cookie verso l'host: vale solo l'header Authorization.
        session = AriaHTTP.cookielessSession(.default)
        let streaming = URLSessionConfiguration.default
        streaming.timeoutIntervalForRequest = config.streamIdleTimeout
        streaming.timeoutIntervalForResource = 30 * 60
        streamSession = AriaHTTP.cookielessSession(streaming)
    }

    // MARK: JSON

    /// `companyScoped: false` per GET /v1/companies: l'azienda è quello che la chiamata
    /// serve a scoprire, e un Company-Id rimasto da un altro account la farebbe fallire.
    @concurrent
    func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [],
                                      companyScoped: Bool = true) async throws -> T {
        let raw = try await data("GET", path, query: query, companyScoped: companyScoped)
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

    /// Un solo retry su 401: si conia un JWT nuovo (GET /api/aria/token) e si riprova.
    @concurrent
    func data(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
              companyScoped: Bool = true) async throws -> Data {
        var retried = false
        while true {
            let req = try await request(method, path, query: query, body: body, companyScoped: companyScoped)
            let (data, response) = try await session.data(for: req)
            if (response as? HTTPURLResponse)?.statusCode == 401, !retried {
                retried = true
                await auth.invalidate()
                continue
            }
            if let offline = AriaHTTP.hostDownError(response) { throw offline }
            try await checkMembership(response, data)
            try AriaHTTP.check(response, data)
            return data
        }
    }

    // MARK: Audio

    /// Trascrizione della dettatura con Whisper sul backend (lib/api/transcription.ts della web):
    /// multipart con `file`, `language` (assente = automatico) e `prompt` (il testo già scritto, per il contesto).
    /// `nil` se il servizio non è attivo (503): resta il testo del riconoscimento sul telefono.
    /// Il limite dei body JSON (WAF) non vale qui: la web carica l'audio sullo stesso percorso.
    @concurrent
    func transcribe(audio: Data, filename: String, mimeType: String,
                    language: String?, prompt: String?) async throws -> String? {
        let boundary = "aria-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        // Finiscono negli header della parte: via virgolette e a capo.
        func header(_ value: String) -> String {
            String(String.UnicodeScalarView(value.unicodeScalars.filter { $0 != "\"" && $0 != "\r" && $0 != "\n" }))
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(header(filename))\"\r\n")
        append("Content-Type: \(header(mimeType))\r\n\r\n")
        body.append(audio)
        append("\r\n")
        if let language { field("language", language) }
        if let prompt, !prompt.isEmpty { field("prompt", prompt) }
        append("--\(boundary)--\r\n")

        var retried = false
        while true {
            var req = try await request("POST", "v1/audio/transcriptions")
            req.httpBody = body
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            let (data, response) = try await session.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode
            if status == 401, !retried {
                retried = true
                await auth.invalidate()
                continue
            }
            if status == 503 { return nil }
            try await checkMembership(response, data)
            try AriaHTTP.check(response, data)
            do { return try JSONDecoder().decode(AriaTranscription.self, from: data).text }
            catch { throw AriaError.decoding("AriaTranscription: \(error)") }
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
                            if AriaHTTP.isHostDown(response) { throw AriaError.serverOffline }
                            try await self.checkMembership(response, errorBody)
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

    /// Operatore disabilitato a sessione aperta: il backend risponde 403 "Not a member of this company".
    /// Gli altri 403 rifiutano solo quell'azione e non sloggano.
    private func checkMembership(_ response: URLResponse, _ data: Data) async throws {
        guard (response as? HTTPURLResponse)?.statusCode == 403, auth.isMobileSession,
              AriaHTTP.detail(from: data) == "Not a member of this company" else { return }
        await auth.discardSession()
        throw AriaError.signedOut
    }

    private func request(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
                         accept: String = "application/json",
                         companyScoped: Bool = true) async throws -> URLRequest {
        // Il limite è del firewall davanti all'API, e vale anche per /v1/mobile.
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
        if companyScoped, let companyId = ctx.companyId {
            req.setValue(companyId, forHTTPHeaderField: "Company-Id")
        }
        req.setValue(config.clientId, forHTTPHeaderField: "X-Aria-Client")
        req.setValue(config.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(accept, forHTTPHeaderField: "Accept")
        if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return req
    }
}

/// Risposta di POST v1/audio/transcriptions (servono solo il testo).
nonisolated struct AriaTranscription: Decodable, Sendable {
    let text: String
}

// MARK: - SSE

nonisolated struct AriaSSEEvent: Sendable {
    let event: String
    let data: String
}

/// Parser incrementale: frame separati da una riga vuota, righe `event:` e `data:`.
/// Un frame oltre `maxFrameBytes` si scarta fino alla riga vuota: un server che non la manda mai non fa crescere la memoria.
nonisolated struct AriaSSEParser {
    static let maxFrameBytes = 1 << 20

    private var buffer: [UInt8] = []
    /// Frame troppo grande: si ignora tutto fino al prossimo confine. `buffer` tiene solo l'ultimo byte.
    private var discarding = false

    mutating func consume(_ byte: UInt8) -> AriaSSEEvent? {
        if byte == 0x0D { return nil }  // normalizza \r\n
        if discarding {
            if byte == 0x0A, buffer.last == 0x0A { discarding = false; buffer.removeAll(keepingCapacity: true) }
            else { buffer.removeAll(keepingCapacity: true); buffer.append(byte) }
            return nil
        }
        buffer.append(byte)
        let n = buffer.count
        guard byte == 0x0A, n >= 2, buffer[n - 2] == 0x0A else {
            if n > Self.maxFrameBytes { buffer = [byte]; discarding = true }
            return nil
        }
        defer { buffer.removeAll(keepingCapacity: true) }
        return Self.parse(buffer)
    }

    mutating func finish() -> AriaSSEEvent? {
        defer { buffer.removeAll(); discarding = false }
        return buffer.isEmpty || discarding ? nil : Self.parse(buffer)
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
