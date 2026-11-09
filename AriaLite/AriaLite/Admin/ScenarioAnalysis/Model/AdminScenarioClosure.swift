//
//  AdminScenarioClosure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una procedura chiusa dall'operatore senza una riparazione confermata (ProcedureClosureView):
//  a che passo si è fermato, cosa ha trovato, perché ha chiuso e cosa ha deciso l'admin.
//

import Foundation

nonisolated struct AdminScenarioClosure: Decodable, Sendable, Identifiable {
    let id: String
    let plantId: String?
    let sessionId: String
    let episode: Int?
    let alarmCode: String?
    let title: String?
    let alarmCategory: String?
    let stepNumber: Int?
    let completedSteps: [String]?
    let findings: [String]?
    let closedBy: String?
    let closedByName: String?
    let closureReasonCode: String?
    let closureDetails: String?
    let closureStepTitle: String?
    /// `unread`, `read`, `approved`, `reassigned`, `dismissed` (vedi AdminScenarioClosureStatus).
    let status: String?
    let readBy: String?
    let decidedBy: String?
    let decisionNote: String?
    let assignedTo: String?
    let assignedToName: String?
    let workOrderId: String?
    private let readAtRaw: String?
    private let decidedAtRaw: String?
    private let createdAtRaw: String?

    private enum CodingKeys: String, CodingKey {
        case id, plantId, sessionId, episode, alarmCode, title, alarmCategory, stepNumber, completedSteps, findings
        case closedBy, closedByName, closureReasonCode, closureDetails, closureStepTitle, status, readBy
        case decidedBy, decisionNote, assignedTo, assignedToName, workOrderId
        case readAtRaw = "readAt"
        case decidedAtRaw = "decidedAt"
        case createdAtRaw = "createdAt"
    }

    var readAt: Date? { AriaDate.parse(readAtRaw) }
    var decidedAt: Date? { AriaDate.parse(decidedAtRaw) }
    var createdAt: Date? { AriaDate.parse(createdAtRaw) }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return alarmCode ?? String(localized: "Procedure")
    }

    var searchableFields: [String] {
        [title, alarmCode, alarmCategory, closedByName, closureDetails, closureReasonCode].compactMap(\.self)
    }
}

/// GET /v1/companies/{company_id}/procedure-closures. `unreadCount` sono sempre gli avvisi aperti, qualunque filtro.
nonisolated struct AdminScenarioClosureList: Decodable, Sendable {
    private let rows: AriaLossyArray<AdminScenarioClosure>?
    let unreadCount: Int?

    private enum CodingKeys: String, CodingKey {
        case rows = "closures"
        case unreadCount
    }

    var closures: [AdminScenarioClosure] { rows?.items ?? [] }
}
