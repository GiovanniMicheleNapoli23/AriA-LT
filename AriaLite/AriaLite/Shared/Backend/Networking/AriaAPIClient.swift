//
//  AriaAPIClient.swift
//  AriaLite
//
//  Created by Giovanni Michele on 25/09/26.
//
//  Client HTTP verso aria-backend: header comuni, retry su 401, richieste JSON (AriaEndpoint + `call`), dettatura,
//  stream SSE di POST /v1/responses (AriaSSE) e stream NDJSON (AriaNDJSON). Azienda e lingua da AriaContext.
//

import Foundation

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
    // Scorciatoie di `call` (AriaEndpoint.swift), per chi descrive la chiamata sul posto.

    /// `companyScoped: false` per GET /v1/companies: l'azienda è quello che la chiamata
    /// serve a scoprire, e un Company-Id rimasto da un altro account la farebbe fallire.
    func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [],
                                      companyScoped: Bool = true) async throws -> T {
        try await call(AriaEndpoint(method: "GET", path: path, query: query, companyScoped: companyScoped))
    }

    /// POST / PATCH / PUT con body JSON; la risposta si decodifica in `T`.
    func send<T: Decodable & Sendable>(_ method: String, _ path: String,
                                       body: some Encodable & Sendable) async throws -> T {
        try await call(AriaEndpoint(method: method, path: path, body: body))
    }

    /// Come `send`, quando la risposta non serve (204 o un oggetto qualsiasi).
    func perform(_ method: String, _ path: String, body: (any Encodable & Sendable)? = nil) async throws {
        let _: AriaNoContent = try await call(AriaEndpoint(method: method, path: path, body: body))
    }

    /// Un solo retry su 401: si conia un JWT nuovo (GET /api/aria/token) e si riprova.
    @concurrent
    func data(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
              headers: [String: String] = [:], companyScoped: Bool = true) async throws -> Data {
        try await response(method, path, query: query, body: body, headers: headers, companyScoped: companyScoped).data
    }

    /// Come `data`, con gli header della risposta (es. `Content-Disposition` di un file scaricato).
    @concurrent
    func response(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
                  headers: [String: String] = [:], companyScoped: Bool = true) async throws -> (data: Data, http: HTTPURLResponse) {
        let (data, response) = try await fetch {
            try await request(method, path, query: query, body: body, headers: headers, companyScoped: companyScoped)
        }
        if let offline = AriaHTTP.hostDownError(response, body: data) { throw offline }
        try await validate(response, data)
        guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
        return (data, http)
    }

    // MARK: Audio

    /// Trascrizione della dettatura sul backend (POST /v1/audio/transcriptions, aperta anche all'operatore):
    /// multipart con `file`, `language` (la lingua di dettatura scelta, assente = automatico) e `prompt`
    /// (il testo già scritto, per il contesto). Il boundary lo sceglie l'app, il `file` è la prima parte.
    /// `nil` se il servizio non è configurato (503): resta il testo del riconoscimento sul telefono.
    /// Gli altri rifiuti (400 registrazione vuota, 413 oltre `maxAudioMb`, 502 provider giù, 403 del firewall)
    /// escono come errore: chi chiama tiene il testo dal vivo (eventualmente ripulito con `polish`).
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
        let multipart = body

        let (data, response) = try await fetch {
            // Il corpo si mette dopo: l'audio supera di molto il limite del firewall sui JSON (`maxBodyBytes`).
            var req = try await request("POST", "v1/audio/transcriptions")
            req.httpBody = multipart
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            return req
        }
        if (response as? HTTPURLResponse)?.statusCode == 503 { return nil }
        try await validate(response, data)
        do { return try JSONDecoder().decode(AriaTranscription.self, from: data).text }
        catch { throw AriaError.decoding("AriaTranscription: \(error)") }
    }

    // MARK: SSE

    /// Apre POST /v1/responses e restituisce gli eventi già interpretati man mano che arrivano.
    /// Cancellare il Task che consuma lo stream chiude la connessione. Un turno `background` va avanti sul server
    /// lo stesso: si ferma con AriaChatAPI.cancelTurn.
    /// `idempotencyKey`: obbligatoria per un turno `background`; la stessa chiave rimanda lo stesso invio
    /// (il server non lo esegue due volte). L'id della risposta arriva in `X-Response-ID`: se c'è, esce come
    /// primo evento `.created`, prima ancora del corpo.
    func stream(_ payload: AriaResponsesRequest,
                idempotencyKey: String? = nil) -> AsyncThrowingStream<AriaStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task(name: "aria.responses.stream") {
                do {
                    let body = try JSONEncoder().encode(payload)
                    let headers = idempotencyKey.map { ["Idempotency-Key": $0] } ?? [:]
                    let (bytes, http) = try await self.openStream {
                        try await self.request("POST", "v1/responses", body: body, headers: headers,
                                               accept: "text/event-stream")
                    }
                    AriaStreamTrace.event("open", "status", bytes: http.statusCode)
                    if let id = http.value(forHTTPHeaderField: "X-Response-ID"), !id.isEmpty {
                        continuation.yield(.created(responseId: id))
                    }
                    var parser = AriaSSEParser()
                    for try await byte in bytes {
                        if let event = parser.consume(byte) {
                            AriaStreamTrace.event("recv", event.event, bytes: event.data.utf8.count)
                            continuation.yield(AriaStreamEvent(event))
                        }
                    }
                    if let event = parser.finish() { continuation.yield(AriaStreamEvent(event)) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: NDJSON

    /// Una richiesta il cui corpo è NDJSON (una riga JSON per evento, es. i run di Agent Studio): le righe escono
    /// man mano che arrivano. Stessi retry 401 ed errori di `stream`. Cancellare chi consuma chiude la connessione;
    /// il server però può continuare il lavoro (un run non si ferma, si annulla con la sua rotta).
    func ndjson(_ method: String, _ path: String, query: [URLQueryItem] = [],
                body: Data? = nil) -> AsyncThrowingStream<AriaJSON, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task(name: "aria.ndjson.stream") {
                do {
                    let (bytes, _) = try await self.openStream {
                        try await self.request(method, path, query: query, body: body, accept: "*/*")
                    }
                    var splitter = AriaNDJSONSplitter()
                    for try await byte in bytes {
                        if let line = splitter.consume(byte) { continuation.yield(line) }
                    }
                    if let line = splitter.finish() { continuation.yield(line) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Private

    /// Manda la richiesta che `make` costruisce; su un 401 si conia un JWT nuovo (GET /api/aria/token) e si riprova
    /// una volta sola. `make` si richiama a ogni tentativo: il token nuovo finisce nell'header.
    private func fetch(_ make: () async throws -> URLRequest) async throws -> (Data, URLResponse) {
        var retried = false
        while true {
            let (data, response) = try await session.data(for: try await make())
            if (response as? HTTPURLResponse)?.statusCode == 401, !retried {
                retried = true
                await auth.invalidate()
                continue
            }
            return (data, response)
        }
    }

    /// Come `fetch`, per una risposta a flusso (SSE o NDJSON). Se il server rifiuta si leggono al più 16 KB del
    /// corpo e si lancia lo stesso errore delle chiamate JSON; un host giù è `serverOffline`.
    private func openStream(_ make: () async throws -> URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        var retried = false
        while true {
            let (bytes, response) = try await streamSession.bytes(for: try await make())
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            if status == 401, !retried {
                retried = true
                await auth.invalidate()
                continue
            }
            if !(200..<300).contains(status) {
                var errorBody = Data()
                for try await byte in bytes {
                    errorBody.append(byte)
                    if errorBody.count >= 16_384 { break }
                }
                if AriaHTTP.isHostDown(response, body: errorBody) { throw AriaError.serverOffline }
                try await validate(response, errorBody)
            }
            await observeAccess(response, nil)
            guard let http = response as? HTTPURLResponse else { throw AriaError.stream("No HTTP response") }
            return (bytes, http)
        }
    }

    /// Diritti, appartenenza all'azienda ed errori del server su una risposta arrivata.
    private func validate(_ response: URLResponse, _ data: Data) async throws {
        await observeAccess(response, data)
        try await checkMembership(response, data)
        try AriaHTTP.check(response, data)
    }

    /// `X-Access-Version` e i 403 dei diritti, per AriaContext.observe.
    private func observeAccess(_ response: URLResponse, _ data: Data?) async {
        guard let http = response as? HTTPURLResponse else { return }
        let code = http.statusCode == 403 ? data.flatMap(AriaHTTP.code(from:)) : nil
        await context.observe(status: http.statusCode, version: http.value(forHTTPHeaderField: "X-Access-Version"),
                              code: code)
    }

    /// Operatore disabilitato a sessione aperta: il backend risponde 403 `not_a_member` ("Not a member of this
    /// company" sui backend precedenti).
    /// Gli altri 403 rifiutano solo quell'azione e non sloggano.
    private func checkMembership(_ response: URLResponse, _ data: Data) async throws {
        guard (response as? HTTPURLResponse)?.statusCode == 403, auth.isMobileSession,
              AriaHTTP.code(from: data) == "not_a_member"
                || AriaHTTP.detail(from: data) == "Not a member of this company" else { return }
        await auth.discardSession()
        throw AriaError.signedOut
    }

    /// Gli id dei percorsi arrivano dal server o da testo estratto dai documenti: un segmento `.` o `..`
    /// (`appending(path:)` non li normalizza) porterebbe la richiesta, con le credenziali, su un'altra rotta.
    static func checkPath(_ path: String) throws {
        guard !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw AriaError.stream(String(localized: "Invalid request."))
        }
    }

    private func request(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Data? = nil,
                         headers: [String: String] = [:], accept: String = "application/json",
                         companyScoped: Bool = true) async throws -> URLRequest {
        // Il limite è del firewall davanti all'API.
        if let body, body.count > config.maxBodyBytes {
            throw AriaError.bodyTooLarge(bytes: body.count, limit: config.maxBodyBytes)
        }
        try Self.checkPath(path)
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
        for (name, value) in headers { req.setValue(value, forHTTPHeaderField: name) }
        return req
    }
}

/// Risposta di POST v1/audio/transcriptions (servono solo il testo).
nonisolated struct AriaTranscription: Decodable, Sendable {
    let text: String
}
