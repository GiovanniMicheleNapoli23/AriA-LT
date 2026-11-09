//
//  AriaEngineService.swift
//  AriaLite
//
//  Created by Giovanni Michele on 30/03/26.
//
//  Networking layer per comunicare con Aria Engine (token + RAG).
//

import Foundation

// MARK: - AriaEngineService

final class AriaEngineService: Sendable {

    /// Host da Info.plist (`AriaVoiceEngineHost`, sempre https); se manca o non è valido, produzione.
    static let defaultBaseURL = AriaConfig.infoURL("AriaVoiceEngineHost") ?? URL(string: "https://api.sinaura-group.com")!

    /// Chiave da Info.plist (`AriaVoiceEngineKey`); vuota → l'header non si manda.
    /// Tutto ciò che sta in Info.plist viaggia dentro il binario dell'app: contro un attaccante
    /// NON è un segreto. La protezione vera deve stare sul server (/token deve autenticare
    /// chi chiama, ad es. con il JWT di Aria); l'xcconfig tiene solo il valore fuori da git.
    static let defaultPassword = (Bundle.main.object(forInfoDictionaryKey: "AriaVoiceEngineKey") as? String)
        .flatMap { $0.isEmpty ? nil : $0 }

    let baseURL: URL
    let password: String?
    /// Senza cookie: l'engine si autentica solo con l'header, niente stato condiviso con `URLSession.shared`.
    private let session = AriaHTTP.cookielessSession(.ephemeral)

    /// - Parameters:
    ///   - baseURL: Base URL del server Aria Engine (default produzione).
    ///   - password: Password per autenticarsi al backend (default da Info.plist). Viene inviata come
    ///              header `x-aria-password` su ogni richiesta.
    init(baseURL: URL = AriaEngineService.defaultBaseURL, password: String? = AriaEngineService.defaultPassword) {
        self.baseURL = baseURL
        self.password = password
    }

    // MARK: - Shared

    /// Istanza condivisa: host e chiave arrivano da Info.plist.
    static let shared = AriaEngineService()

    // MARK: - Token

    /// Risposta dal server: il token è nel campo `value` al primo livello.
    struct TokenResponse: Codable, Sendable {
        let value: String
        let expires_at: Int
    }

    /// Genera un token effimero per la sessione Realtime.
    func getToken() async throws -> String {
        AriaVoiceTrace.step("token", "GET /token key=\(password != nil)")
        let (data, response) = try await performGET(path: "/token")

        guard let http = response as? HTTPURLResponse else {
            throw AriaEngineError.tokenFailed(status: -1)
        }
        AriaVoiceTrace.response("token", http, data)

        guard http.statusCode == 200 else {
            throw AriaEngineError.tokenFailed(status: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return decoded.value
    }

    // MARK: - RAG Search

    struct RAGRequest: Codable, Sendable {
        let query: String
        let topK: Int
    }

    struct RAGResponse: Codable, Sendable {
        let results: [RAGResult]
    }

    struct RAGResult: Codable, Sendable {
        let text: String
        let score: Double
        let semanticScore: Double
        let bm25Score: Double
        let meta: RAGMeta?
    }

    struct RAGMeta: Codable, Sendable {
        let filename: String?
        let chunkIndex: Int?
    }

    /// Cerca nella knowledge base aziendale.
    func searchKnowledgeBase(query: String, topK: Int = 5) async throws -> [RAGResult] {
        let (data, response) = try await performPOST(
            path: "/rag/search",
            body: RAGRequest(query: query, topK: topK)
        )

        guard let http = response as? HTTPURLResponse else {
            throw AriaEngineError.ragSearchFailed(status: -1)
        }

        guard http.statusCode == 200 else {
            throw AriaEngineError.ragSearchFailed(status: http.statusCode)
        }

        return try JSONDecoder().decode(RAGResponse.self, from: data).results
    }

    /// Formatta i risultati RAG in una stringa di contesto per il modello.
    func formatRAGResults(_ results: [RAGResult]) -> String {
        guard !results.isEmpty else { return "No results found in the knowledge base." }
        return results.enumerated().map { i, r in
            "[\(i + 1)] (\(r.meta?.filename ?? "doc")) \(r.text)"
        }.joined(separator: "\n\n")
    }

    // MARK: - HTTP Helpers

    private func applyAuth(_ request: inout URLRequest) {
        if let pwd = password, !pwd.isEmpty {
            request.setValue(pwd, forHTTPHeaderField: "x-aria-password")
        }
    }

    private func performGET(path: String) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "GET"
        applyAuth(&request)
        return try await session.data(for: request)
    }

    private func performPOST(path: String, body: some Encodable) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = try JSONEncoder().encode(body)
        return try await session.data(for: request)
    }

    // MARK: - Errors

    enum AriaEngineError: LocalizedError {
        case badURL
        case tokenFailed(status: Int)
        case ragSearchFailed(status: Int)
        /// Errore locale della sessione vocale: il testo è fisso, mai preso dal server.
        case sessionFailed(String)

        var errorDescription: String? {
            switch self {
            case .badURL:
                return "Invalid URL for Aria Engine"
            case .tokenFailed(let status):
                return "Token failed (HTTP \(status))"
            case .ragSearchFailed(let status):
                return "RAG search failed (HTTP \(status))"
            case .sessionFailed(let message):
                return message
            }
        }
    }
}
