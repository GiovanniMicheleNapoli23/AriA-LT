//
//  AdminAlarmRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle rotte degli allarmi: PATCH (AlarmUpdate), ai-improve (AlarmAIImproveRequest),
//  bulk-approve e agents/diagnostic (DiagnosticAgentRequest). Si codificano in snake_case dalla chiamata
//  (tranne bulk-approve, che ha già le sue chiavi).
//

import Foundation

/// PATCH /v1/alarms/{id}: solo i campi cambiati. Un campo esterno `nil` non si manda; `.some(nil)` si manda
/// come `null` e svuota il campo sul server. Il codice dell'allarme non si modifica da qui.
nonisolated struct AdminAlarmUpdate: Encodable, Sendable {
    var description: String??
    var status: String??
    var assetTag: String??
    var category: String??
    var zone: String??
    var hmiPage: String??
    var typicalCauses: [String]??
    var resolutionSteps: [String]??

    private enum CodingKeys: String, CodingKey {
        case description, status, assetTag, category, zone, hmiPage, typicalCauses, resolutionSteps
    }

    /// Niente da mandare.
    var isEmpty: Bool {
        description == nil && status == nil && assetTag == nil && category == nil && zone == nil
            && hmiPage == nil && typicalCauses == nil && resolutionSteps == nil
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeChange(description, .description)
        try c.encodeChange(status, .status)
        try c.encodeChange(assetTag, .assetTag)
        try c.encodeChange(category, .category)
        try c.encodeChange(zone, .zone)
        try c.encodeChange(hmiPage, .hmiPage)
        try c.encodeChange(typicalCauses, .typicalCauses)
        try c.encodeChange(resolutionSteps, .resolutionSteps)
    }
}

private nonisolated extension KeyedEncodingContainer {
    /// Un cambiamento: assente non si scrive, `nil` si scrive come `null`.
    mutating func encodeChange<T: Encodable>(_ change: T??, _ key: Key) throws {
        guard case .some(let value) = change else { return }
        if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
    }
}

/// POST /v1/alarms/{id}/ai-improve. I `nil` non si scrivono.
nonisolated struct AdminAlarmImproveRequest: Encodable, Sendable {
    var action: String
    var customPrompt: String?
    var language: String?
}

/// POST /v1/alarms/bulk-approve: il corpo è un oggetto libero. Gli stessi id vanno sotto `ids` e `alarm_ids`
/// (come fa la revisione delle estrazioni), così vale qualunque delle due chiavi il server legga.
nonisolated struct AdminAlarmBulkApproveBody: Encodable, Sendable {
    let ids: [String]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(["ids": ids, "alarm_ids": ids])
    }
}

/// POST /v1/agents/diagnostic.
nonisolated struct AdminAlarmDiagnosticRequest: Encodable, Sendable {
    var alarmCode: String
    var assetTag: String?
    var additionalContext: String?
}
