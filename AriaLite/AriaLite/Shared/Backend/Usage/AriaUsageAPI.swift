//
//  AriaUsageAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le tre rotte dei crediti, aperte a ogni membro (operatori compresi): configurazione, stima di una risposta e saldo.
//  Config e saldo rispondono 503 quando il piano o le cifre non si leggono: niente numeri e un "Riprova", mai cifre
//  tenute nell'app.
//

import Foundation

nonisolated struct AriaUsageAPI: Sendable {
    let api: AriaAPIClient

    /// GET /v1/usage/config: piano, livelli di impegno, peso delle azioni.
    func config() async throws -> AriaUsageConfig {
        try await api.call(.get("v1/usage/config"))
    }

    /// POST /v1/usage/estimate: il costo di una risposta di chat a questo livello (gratis, 60 s di cache a chi chiama).
    func estimate(_ level: AriaEffortLevel) async throws -> AriaUsageEstimate {
        try await api.call(.post("v1/usage/estimate", body: AriaUsageEstimateRequest(effort: level)))
    }

    /// GET /v1/usage/allowance: il saldo adesso.
    func allowance() async throws -> AriaAllowance {
        try await api.call(.get("v1/usage/allowance"))
    }
}
