//
//  AdminAgentStudioApproval.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un passo di workflow fermo ad aspettare una persona (GET approvals, approvals/{id}).
//  La forma non è documentata (oggetto libero): ogni campo si cerca sotto più nomi, e gli argomenti
//  dell'azione proposta restano JSON da mostrare in sola lettura.
//

import Foundation

nonisolated struct AdminAgentStudioApproval: AdminAgentStudioJSONModel, Identifiable, Hashable {
    static let listKeys = ["approvals", "items"]

    let id: String
    let status: String?
    let title: String?
    let instructions: String?
    let workflowId: String?
    let workflowName: String?
    let runId: String?
    let nodeId: String?
    let agentName: String?
    let capability: String?
    let connectorId: String?
    let riskTier: String?
    let requiredRole: String?
    let approvers: [String]
    let requestedBy: String?
    let createdAt: Date?
    let expiresAt: Date?
    let decidedAt: Date?
    let decidedBy: String?
    let decisionComment: String?
    /// Gli argomenti dell'azione da approvare (chiave → valore).
    let arguments: [String: AriaJSON]

    init?(json: AriaJSON) {
        let outer = AdminAgentStudioFields(json)
        let fields = outer.object("approval").isEmpty ? outer : outer.object("approval")
        guard let id = fields.string("id", "approvalId") else { return nil }
        self.id = id
        status = fields.string("status", "state")
        title = fields.string("title", "name", "stepTitle", "summary")
        instructions = fields.string("instructions", "message", "description", "reason")
        workflowId = fields.string("workflowId")
        workflowName = fields.string("workflowName")
        runId = fields.string("runId")
        nodeId = fields.string("nodeId", "stepId")
        agentName = fields.string("agentName", "agent")
        capability = fields.string("capability", "operation", "action")
        connectorId = fields.string("connectorId", "connector", "provider")
        riskTier = fields.string("riskTier", "tier", "risk")
        requiredRole = fields.string("requiredRole", "minRole")
        approvers = fields.strings("approvers", "approverIds")
        requestedBy = fields.string("requestedBy", "startedBy", "createdBy")
        createdAt = fields.date("createdAt", "requestedAt", "created")
        expiresAt = fields.date("expiresAt", "deadline")
        decidedAt = fields.date("decidedAt", "resolvedAt")
        decidedBy = fields.string("decidedBy", "resolvedBy")
        decisionComment = fields.string("comment", "decisionComment", "note")
        arguments = fields.value("args", "arguments", "params", "proposedArgs")?.objectValue ?? [:]
    }

    /// Titolo da mostrare anche quando il server non ne manda uno.
    var displayTitle: String {
        title ?? capability ?? nodeId ?? String(localized: "Approval")
    }

    var isPending: Bool { status == nil || status?.lowercased() == "pending" }
}

/// Il filtro della lista: gli stati di GET approvals?status=…, più "tutte".
nonisolated enum AdminAgentStudioApprovalFilter: String, CaseIterable, Identifiable, Sendable {
    case pending, approved, rejected, expired, cancelled, all

    var id: String { rawValue }

    var label: String {
        self == .all ? String(localized: "All") : AdminAgentStudioStatus.label(for: rawValue)
    }

    /// Il valore per il server: "tutte" vuol dire nessun parametro.
    var query: String? { self == .all ? nil : rawValue }
}

/// La decisione su un'approvazione. `edit` (modifica e approva) non c'è: chiede di riscrivere gli argomenti.
nonisolated enum AdminAgentStudioDecision: String, Sendable, Identifiable {
    case approve, reject

    var id: String { rawValue }
}
