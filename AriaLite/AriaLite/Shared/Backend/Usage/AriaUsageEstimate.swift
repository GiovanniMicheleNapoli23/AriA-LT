//
//  AriaUsageEstimate.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  POST /v1/usage/estimate: quanto costerebbe una risposta a un dato livello di impegno. Gratuita. Il body accetta
//  solo `action_type`, `effort`, `context_tokens` e `count`: qualsiasi altra chiave è un 422.
//

import Foundation

nonisolated struct AriaUsageEstimateRequest: Encodable, Sendable {
    var actionType = "chat.reply"
    var effort: AriaEffortLevel

    private enum CodingKeys: String, CodingKey {
        case actionType = "action_type", effort
    }
}

nonisolated struct AriaUsageEstimate: Decodable, Sendable, Equatable {
    /// Il livello che il server userebbe davvero: la risposta vale solo se è quello chiesto.
    var effortEffective: String?
    var creditsEach: Decimal?
    /// Quanto toglierebbe dal saldo; è la base dei "replies a day".
    var allowanceImpactEach: Decimal?
    var degraded = false

    private enum CodingKeys: String, CodingKey {
        case effortEffective = "effort_effective", creditsEach = "credits_each"
        case allowanceImpactEach = "allowance_impact_each", degraded
    }

    init(effortEffective: String? = nil, creditsEach: Decimal? = nil, allowanceImpactEach: Decimal? = nil,
         degraded: Bool = false) {
        self.effortEffective = effortEffective
        self.creditsEach = creditsEach
        self.allowanceImpactEach = allowanceImpactEach
        self.degraded = degraded
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        effortEffective = c.ariaLenient(.effortEffective)
        creditsEach = c.ariaDecimal(.creditsEach)
        allowanceImpactEach = c.ariaDecimal(.allowanceImpactEach)
        degraded = c.ariaLenient(.degraded) ?? false
    }
}
