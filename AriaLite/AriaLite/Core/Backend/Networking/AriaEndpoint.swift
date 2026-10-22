//
//  AriaEndpoint.swift
//  AriaLite
//
//  Created by Giovanni Michele on 19/10/26.
//
//  Una chiamata REST descritta come dato: metodo, percorso, query, body e header in più.
//  Una rotta nuova è una riga (vedi AriaChatAPI); `AriaAPIClient.call` fa il resto: header comuni,
//  Company-Id, retry su 401, errori del server (`AriaHTTP.check`) e decodifica della risposta.
//

import Foundation

nonisolated struct AriaEndpoint<Response: Decodable & Sendable>: Sendable {
    var method: String
    var path: String
    var query: [URLQueryItem] = []
    /// Si codifica in JSON al momento della chiamata.
    var body: (any Encodable & Sendable)? = nil
    var headers: [String: String] = [:]
    /// `false` solo per GET /v1/companies: l'azienda è quello che la chiamata serve a scoprire.
    var companyScoped = true

    static func get(_ path: String, query: KeyValuePairs<String, String> = [:]) -> Self {
        Self(method: "GET", path: path, query: query.map { URLQueryItem(name: $0.key, value: $0.value) })
    }

    static func post(_ path: String, body: (any Encodable & Sendable)? = nil) -> Self {
        Self(method: "POST", path: path, body: body)
    }

    static func put(_ path: String, body: any Encodable & Sendable) -> Self {
        Self(method: "PUT", path: path, body: body)
    }

    static func patch(_ path: String, body: any Encodable & Sendable) -> Self {
        Self(method: "PATCH", path: path, body: body)
    }

    static func delete(_ path: String) -> Self {
        Self(method: "DELETE", path: path)
    }
}

/// La risposta non si legge (204, o un oggetto che non serve): `call` non la decodifica.
nonisolated struct AriaNoContent: Decodable, Sendable {
    init() {}
    init(from decoder: any Decoder) throws {}
}

extension AriaAPIClient {
    @concurrent
    func call<Response>(_ endpoint: AriaEndpoint<Response>) async throws -> Response {
        let body = try endpoint.body.map { try JSONEncoder().encode($0) }
        let raw = try await data(endpoint.method, endpoint.path, query: endpoint.query, body: body,
                                 headers: endpoint.headers, companyScoped: endpoint.companyScoped)
        if let none = AriaNoContent() as? Response { return none }
        do { return try JSONDecoder().decode(Response.self, from: raw) }
        catch { throw AriaError.decoding("\(Response.self): \(error)") }
    }
}
