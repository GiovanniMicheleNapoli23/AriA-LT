//
//  AdminScenario.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Uno scenario ricorrente (ScenarioView del backend): un allarme o una procedura che Aria ha già gestito,
//  con quante volte, come è andata e i fatti imparati usati. Lettura tollerante: serve solo l'id.
//  Queste rotte sono in camelCase sul filo; le date arrivano come testo e si leggono con AriaDate.
//

import Foundation

nonisolated struct AdminScenario: Decodable, Sendable, Identifiable {
    let id: String
    let scenarioKey: String?
    /// `alarm` o `procedure` (vedi AdminScenarioKind).
    let kind: String?
    let title: String?
    let description: String?
    let summary: String?
    let alarmCode: String?
    let plantId: String?
    let supportCount: Int?
    let successCount: Int?
    let failureCount: Int?
    let unclearCount: Int?
    let forcedClosureCount: Int?
    let firstShotCount: Int?
    let metrics: AdminScenarioMetrics?
    let lastVerdict: String?
    let lastSessionId: String?
    let lastEpisode: Int?
    private let factRows: AriaLossyArray<AdminScenarioFact>?
    private let lastAssessedAtRaw: String?
    private let updatedAtRaw: String?

    private enum CodingKeys: String, CodingKey {
        case id, scenarioKey, kind, title, description, summary, alarmCode, plantId
        case supportCount, successCount, failureCount, unclearCount, forcedClosureCount, firstShotCount
        case metrics, lastVerdict, lastSessionId, lastEpisode
        case factRows = "facts"
        case lastAssessedAtRaw = "lastAssessedAt"
        case updatedAtRaw = "updatedAt"
    }

    var facts: [AdminScenarioFact] { factRows?.items ?? [] }
    var lastAssessedAt: Date? { AriaDate.parse(lastAssessedAtRaw) }
    var updatedAt: Date? { AriaDate.parse(updatedAtRaw) }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return alarmCode ?? scenarioKey ?? String(localized: "Untitled scenario")
    }

    /// Le sessioni su cui si regge lo scenario.
    var sessions: Int { supportCount ?? 0 }

    /// Testo in cui cerca la lista.
    var searchableFields: [String] {
        [title, alarmCode, summary, description, scenarioKey].compactMap(\.self)
    }
}

/// Le cifre derivate. I tassi sono frazioni 0…1 e `nil` finché non c'è una base per calcolarli.
nonisolated struct AdminScenarioMetrics: Decodable, Sendable {
    let conclusiveCount: Int?
    /// Lo storico: dei tentativi conclusi, quanti risolti.
    let reliability: Double?
    let accuracy: Double?
    let avgSteps: Double?
    let mttrAvgMin: Double?
    let mttrExpectedMin: Double?
    /// Cosa aspettarsi la prossima volta (stima smussata), con il suo intervallo al 90%.
    let forecastSuccessRate: Double?
    let forecastLow: Double?
    let forecastHigh: Double?
    let forecastConfidence: String?
    let trend: String?
    let maturity: String?
    let reviewedCount: Int?
    let reviewedShare: Double?
    let avgRating: Double?
    let reportedIssueCount: Int?
}

/// Un fatto imparato usato per gestire lo scenario (l'id è quello della conoscenza imparata).
nonisolated struct AdminScenarioFact: Decodable, Sendable, Identifiable {
    let factId: String
    let content: String
    let status: String?
    let hitCount: Int?

    var id: String { factId }
}

/// GET /v1/companies/{company_id}/scenarios.
nonisolated struct AdminScenarioListResponse: Decodable, Sendable {
    private let rows: AriaLossyArray<AdminScenario>?
    let totalScenarios: Int?
    let totalSessions: Int?
    let overallReliability: Double?
    let provenCount: Int?

    private enum CodingKeys: String, CodingKey {
        case rows = "scenarios"
        case totalScenarios, totalSessions, overallReliability, provenCount
    }

    var scenarios: [AdminScenario] { rows?.items ?? [] }
}
