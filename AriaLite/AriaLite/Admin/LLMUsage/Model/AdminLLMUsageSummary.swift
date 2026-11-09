//
//  AdminLLMUsageSummary.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il riepilogo del consumo AI di un periodo (GET /v1/usage/summary): totali, giorni e modelli.
//  Tutti i conteggi sono opzionali nello schema: se mancano valgono zero.
//

import Foundation

nonisolated struct AdminLLMUsageSummary: Decodable, Sendable, Equatable {
    let rangeFrom: String?
    let rangeTo: String?
    let totals: AdminLLMUsageTotals
    let byDay: [AdminLLMUsageDay]
    let byModel: [AdminLLMUsageModel]

    private enum CodingKeys: String, CodingKey {
        case rangeFrom, rangeTo, totals, byDay, byModel
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rangeFrom = try c.decodeIfPresent(String.self, forKey: .rangeFrom)
        rangeTo = try c.decodeIfPresent(String.self, forKey: .rangeTo)
        totals = try c.decodeIfPresent(AdminLLMUsageTotals.self, forKey: .totals) ?? .empty
        byDay = (try? c.decodeIfPresent(AriaLossyArray<AdminLLMUsageDay>.self, forKey: .byDay))?.items ?? []
        byModel = (try? c.decodeIfPresent(AriaLossyArray<AdminLLMUsageModel>.self, forKey: .byModel))?.items ?? []
    }
}

/// I totali (`SessionTotals`): token, costo in euro, chiamate e quelle senza prezzo.
nonisolated struct AdminLLMUsageTotals: Decodable, Sendable, Equatable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let costEur: Double
    let nCalls: Int
    let unpricedCalls: Int

    static let empty = AdminLLMUsageTotals(promptTokens: 0, completionTokens: 0, totalTokens: 0,
                                           costEur: 0, nCalls: 0, unpricedCalls: 0)

    init(promptTokens: Int, completionTokens: Int, totalTokens: Int, costEur: Double, nCalls: Int, unpricedCalls: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.costEur = costEur
        self.nCalls = nCalls
        self.unpricedCalls = unpricedCalls
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        promptTokens = try c.decodeIfPresent(Int.self, forKey: .promptTokens) ?? 0
        completionTokens = try c.decodeIfPresent(Int.self, forKey: .completionTokens) ?? 0
        totalTokens = try c.decodeIfPresent(Int.self, forKey: .totalTokens) ?? 0
        costEur = try c.decodeIfPresent(Double.self, forKey: .costEur) ?? 0
        nCalls = try c.decodeIfPresent(Int.self, forKey: .nCalls) ?? 0
        unpricedCalls = try c.decodeIfPresent(Int.self, forKey: .unpricedCalls) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case promptTokens, completionTokens, totalTokens, costEur, nCalls, unpricedCalls
    }
}

/// Un giorno del periodo (`UsageSummaryBucket`). `bucket` è la data, di solito `AAAA-MM-GG`.
nonisolated struct AdminLLMUsageDay: Decodable, Sendable, Equatable {
    let bucket: String
    let totals: AdminLLMUsageTotals

    init(from decoder: any Decoder) throws {
        let totals = try AdminLLMUsageTotals(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try c.decode(String.self, forKey: .bucket)
        self.totals = totals
    }

    private enum CodingKeys: String, CodingKey { case bucket }
}

/// Una riga per modello (`UsageSummaryByModel`). Il costo è `nil` se il modello non ha prezzo.
nonisolated struct AdminLLMUsageModel: Decodable, Sendable, Equatable, Identifiable {
    let provider: String
    let model: String
    let stage: String
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let costEur: Double?
    let nCalls: Int
    let unpricedCalls: Int

    var id: String { "\(provider)|\(model)|\(stage)" }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = try c.decode(String.self, forKey: .provider)
        model = try c.decode(String.self, forKey: .model)
        stage = try c.decodeIfPresent(String.self, forKey: .stage) ?? "agent"
        promptTokens = try c.decodeIfPresent(Int.self, forKey: .promptTokens) ?? 0
        completionTokens = try c.decodeIfPresent(Int.self, forKey: .completionTokens) ?? 0
        totalTokens = try c.decodeIfPresent(Int.self, forKey: .totalTokens) ?? 0
        costEur = try c.decodeIfPresent(Double.self, forKey: .costEur)
        nCalls = try c.decodeIfPresent(Int.self, forKey: .nCalls) ?? 0
        unpricedCalls = try c.decodeIfPresent(Int.self, forKey: .unpricedCalls) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case provider, model, stage, promptTokens, completionTokens, totalTokens, costEur, nCalls, unpricedCalls
    }
}
