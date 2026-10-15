//
//  StubNetwork.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 15/10/26.
//
//  Rete finta per i test del backend: un URLProtocol che registra ogni richiesta e risponde con quello
//  che il test ha preparato. Si aggancia a tutte le sessioni dell'app tramite AriaHTTP.extraProtocolClasses.
//  Le richieste senza risposta preparata ricevono 599, così un percorso inatteso si vede subito.
//

import Foundation
@testable import AriaLite

/// Una risposta preparata. `delay`: secondi prima di rispondere. `error`: la rete cade (nessuna risposta).
nonisolated struct Reply: Sendable {
    var status = 200
    var headers: [String: String] = [:]
    var body = Data()
    var delay: TimeInterval = 0
    var error: URLError.Code?

    static func json(_ text: String = "{}", status: Int = 200, headers: [String: String] = [:],
                     delay: TimeInterval = 0) -> Reply {
        var all = headers
        all["Content-Type"] = "application/json"
        return Reply(status: status, headers: all, body: Data(text.utf8), delay: delay)
    }

    /// Il gateway non raggiunge il server: l'host è giù.
    static func hostDown() -> Reply {
        Reply(status: 503, headers: ["Content-Type": "text/html"], body: Data("<html>unavailable</html>".utf8))
    }

    static func failing(_ code: URLError.Code, delay: TimeInterval = 0) -> Reply {
        Reply(delay: delay, error: code)
    }

    static let noContent = Reply(status: 204)
}

/// Una richiesta arrivata alla rete finta.
nonisolated struct Call: Sendable {
    let method: String
    let host: String
    let path: String
    let query: String?
    /// Nomi in minuscolo.
    let headers: [String: String]
    let body: Data

    func header(_ name: String) -> String? { headers[name.lowercased()] }

    var bodyText: String { String(decoding: body, as: UTF8.self) }

    /// Il body come JSON (`nil` se non lo è).
    var json: [String: Any]? { (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] }
}

nonisolated final class StubServer: @unchecked Sendable {
    static let shared = StubServer()

    private let lock = NSLock()
    private var routes: [String: [Reply]] = [:]
    private var recorded: [Call] = []

    func reset() {
        lock.withLock {
            routes = [:]
            recorded = []
        }
    }

    /// `key` = "METODO /percorso" oppure "METODO /percorso?query". Le risposte escono in ordine; l'ultima si ripete.
    func route(_ key: String, _ replies: Reply...) {
        lock.withLock { routes[key] = replies }
    }

    func record(_ call: Call) {
        lock.withLock { recorded.append(call) }
    }

    func next(for key: String) -> Reply? {
        lock.withLock {
            guard var queue = routes[key], !queue.isEmpty else { return nil }
            let reply = queue.count > 1 ? queue.removeFirst() : queue[0]
            routes[key] = queue
            return reply
        }
    }

    var calls: [Call] { lock.withLock { recorded } }

    func calls(_ key: String) -> [Call] {
        calls.filter { "\($0.method) \($0.path)" == key }
    }

    /// Le richieste a percorsi senza risposta preparata.
    var unstubbed: [Call] {
        lock.withLock {
            recorded.filter { call in
                let plain = "\(call.method) \(call.path)"
                return routes[plain] == nil && routes[call.query.map { "\(plain)?\($0)" } ?? ""] == nil
            }
        }
    }
}

nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private let stopLock = NSLock()
    private var stopped = false

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let request = self.request
        let url = request.url!
        var headers: [String: String] = [:]
        for (name, value) in request.allHTTPHeaderFields ?? [:] { headers[name.lowercased()] = value }
        let call = Call(method: request.httpMethod ?? "GET", host: url.host() ?? "", path: url.path(),
                        query: url.query(), headers: headers, body: Self.body(of: request))
        StubServer.shared.record(call)

        // Una risposta preparata per "METODO /percorso?query" vince su quella per "METODO /percorso".
        let plain = "\(call.method) \(call.path)"
        let reply = (call.query.flatMap { StubServer.shared.next(for: "\(plain)?\($0)") })
            ?? StubServer.shared.next(for: plain)
            ?? Reply(status: 599, body: Data("unstubbed \(call.method) \(call.path)".utf8))
        let deliver = { [self] in
            stopLock.lock()
            let skip = stopped
            stopLock.unlock()
            guard !skip else { return }
            if let error = reply.error {
                client?.urlProtocol(self, didFailWithError: URLError(error))
                return
            }
            let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: "HTTP/1.1",
                                           headerFields: reply.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: reply.body)
            client?.urlProtocolDidFinishLoading(self)
        }
        if reply.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + reply.delay, execute: deliver)
        } else {
            deliver()
        }
    }

    override func stopLoading() {
        stopLock.lock()
        stopped = true
        stopLock.unlock()
    }

    /// URLSession passa il body come stream: lo si legge per intero.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
