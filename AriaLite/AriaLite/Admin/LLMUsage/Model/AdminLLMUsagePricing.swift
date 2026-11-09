//
//  AdminLLMUsagePricing.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il listino dei modelli (GET /v1/usage/pricing): prezzo di input e di output per milione di token.
//

import Foundation

nonisolated struct AdminLLMUsagePricing: Decodable, Sendable, Equatable {
    let version: String
    let currency: String
    let fxSource: String
    let rows: [AdminLLMUsagePriceRow]

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "EUR"
        fxSource = try c.decodeIfPresent(String.self, forKey: .fxSource) ?? ""
        rows = (try? c.decodeIfPresent(AriaLossyArray<AdminLLMUsagePriceRow>.self, forKey: .rows))?.items ?? []
    }

    private enum CodingKeys: String, CodingKey { case version, currency, fxSource, rows }
}

nonisolated struct AdminLLMUsagePriceRow: Decodable, Sendable, Equatable, Identifiable {
    let provider: String
    let model: String
    let inputPerMtokEur: Double
    let outputPerMtokEur: Double

    var id: String { "\(provider)|\(model)" }
}
