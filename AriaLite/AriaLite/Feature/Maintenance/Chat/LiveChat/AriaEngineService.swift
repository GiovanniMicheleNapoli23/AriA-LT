//
//  AriaEngineService.swift
//  Aria_v1.0
//
//  Networking layer per comunicare con Aria Engine (token + RAG).
//  Ref: iOS_Integration_Guide.md §5
//

import Foundation

// MARK: - AriaEngineService

final class AriaEngineService: Sendable {

    static let defaultBaseURL = "https://api.sinaura-group.com"

    let baseURL: String
    let password: String?

    /// - Parameters:
    ///   - baseURL: Base URL del server Aria Engine (default produzione).
    ///   - password: Password per autenticarsi al backend. Viene inviata come
    ///              header `x-aria-password` su ogni richiesta.
    init(baseURL: String = AriaEngineService.defaultBaseURL, password: String? = nil) {
        self.baseURL = baseURL
        self.password = password
    }

    // MARK: - Shared (singleton configurabile)

    /// Istanza condivisa — va configurata all'avvio dell'app con `AriaEngineService.configure(...)`.
    nonisolated(unsafe) static var shared = AriaEngineService()

    /// Configura l'istanza shared con le credenziali corrette.
    static func configure(baseURL: String = defaultBaseURL, password: String) {
        shared = AriaEngineService(baseURL: baseURL, password: password)
    }

    // MARK: - Token

    /// Risposta dal server: il token è nel campo `value` al primo livello.
    struct TokenResponse: Codable, Sendable {
        let value: String
        let expires_at: Int
    }

    /// Genera un token effimero per la sessione Realtime.
    func getToken() async throws -> String {
        print("[AriaEngine] getToken() → GET \(baseURL)/token  (password: \(password != nil ? "✅ set" : "⚠️ nil"))")
        let (data, response) = try await performGET(path: "/token")

        guard let http = response as? HTTPURLResponse else {
            throw AriaEngineError.tokenFailed(status: -1, body: "No HTTP response")
        }

        let body = String(data: data, encoding: .utf8) ?? "(binary)"
        print("[AriaEngine] getToken() → HTTP \(http.statusCode)  body: \(body.prefix(200))")

        guard http.statusCode == 200 else {
            throw AriaEngineError.tokenFailed(status: http.statusCode, body: body)
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
            throw AriaEngineError.ragSearchFailed(status: -1, body: "No HTTP response")
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(binary)"
            throw AriaEngineError.ragSearchFailed(status: http.statusCode, body: body)
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

    // MARK: - RAG Status

    struct RAGStatus: Codable, Sendable {
        let totalChunks: Int
        let files: [String]
        let fileCount: Int
    }

    /// Stato della knowledge base (numero documenti caricati).
    func getRAGStatus() async throws -> RAGStatus {
        let (data, _) = try await performGET(path: "/rag/status")
        return try JSONDecoder().decode(RAGStatus.self, from: data)
    }

    // MARK: - HTTP Helpers

    private func makeURL(path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw AriaEngineError.badURL
        }
        return url
    }

    private func applyAuth(_ request: inout URLRequest) {
        if let pwd = password, !pwd.isEmpty {
            request.setValue(pwd, forHTTPHeaderField: "x-aria-password")
        }
    }

    private func performGET(path: String) async throws -> (Data, URLResponse) {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuth(&request)
        return try await URLSession.shared.data(for: request)
    }

    private func performPOST(path: String, body: some Encodable) async throws -> (Data, URLResponse) {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = try JSONEncoder().encode(body)
        return try await URLSession.shared.data(for: request)
    }

    // MARK: - Errors

    enum AriaEngineError: LocalizedError {
        case badURL
        case tokenFailed(status: Int, body: String)
        case ragSearchFailed(status: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .badURL:
                return "Invalid URL for Aria Engine"
            case .tokenFailed(let status, let body):
                return "Token failed (HTTP \(status)): \(body)"
            case .ragSearchFailed(let status, let body):
                return "RAG search failed (HTTP \(status)): \(body)"
            }
        }
    }
}
