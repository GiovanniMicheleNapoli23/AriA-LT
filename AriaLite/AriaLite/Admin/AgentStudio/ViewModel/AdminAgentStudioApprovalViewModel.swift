//
//  AdminAgentStudioApprovalViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un'approvazione, come /agent-studio/approvals/{id} della web: cosa chiede il passo,
//  con quali argomenti, e la decisione (approva o rifiuta, con una nota). Deciso, il run riparte sul server.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioApprovalViewModel {
    let backend: AriaBackend
    let approvalId: String

    private(set) var approval: AdminAgentStudioApproval?
    private(set) var loadError: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    /// La nota che accompagna la decisione (facoltativa).
    var comment = ""
    private(set) var deciding: AdminAgentStudioDecision?
    /// La decisione di cui si chiede conferma.
    var decisionToConfirm: AdminAgentStudioDecision?
    var actionError: String?

    var showsDecisionConfirmation: Bool {
        get { decisionToConfirm != nil }
        set { if !newValue { decisionToConfirm = nil } }
    }

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    @ObservationIgnored private let onDecided: () async -> Void

    init(backend: AriaBackend, approvalId: String, seed: AdminAgentStudioApproval?, onDecided: @escaping () async -> Void) {
        self.backend = backend
        self.approvalId = approvalId
        self.approval = seed
        self.onDecided = onDecided
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            approval = try await backend.api.call(AdminAgentStudioAPI.approval(id: approvalId)).value
            loadError = nil
        } catch {
            guard let message = AdminAgentStudioFailure.message(for: error, backend: backend) else { return }
            loadError = message
        }
        hasLoaded = true
    }

    // MARK: Scheda

    var title: String { approval?.displayTitle ?? String(localized: "Approval") }

    var fields: [AdminAssetField] {
        guard let approval else { return [] }
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Status"), approval.status.map(AdminAgentStudioStatus.label(for:)))
        add(String(localized: "Workflow"), approval.workflowName ?? approval.workflowId)
        add(String(localized: "Step"), approval.nodeId)
        add(String(localized: "Agent"), approval.agentName)
        add(String(localized: "Connector"), approval.connectorId)
        add(String(localized: "Action"), approval.capability)
        add(String(localized: "Risk tier"), approval.riskTier)
        add(String(localized: "Required role"), approval.requiredRole?.capitalized(with: .current))
        add(String(localized: "Approvers"), approval.approvers.joined(separator: ", "))
        add(String(localized: "Requested by"), approval.requestedBy)
        add(String(localized: "Requested"), approval.createdAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Expires"), approval.expiresAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Decided by"), approval.decidedBy)
        add(String(localized: "Decided"), approval.decidedAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Note"), approval.decisionComment)
        return rows
    }

    /// Gli argomenti dell'azione proposta, in ordine di nome; i valori complessi come JSON compatto.
    var argumentRows: [AdminAssetField] {
        guard let approval else { return [] }
        return approval.arguments.keys.sorted().compactMap { key in
            guard let value = approval.arguments[key] else { return nil }
            let text = value.stringValue ?? value.compactDescription
            return AdminAssetField(title: key, value: text.isEmpty ? "—" : text)
        }
    }

    /// Scaduta: si può solo leggere.
    var isExpired: Bool {
        guard let expires = approval?.expiresAt else { return false }
        return expires < .now
    }

    var canDecide: Bool { (approval?.isPending ?? false) && deciding == nil && !isExpired }

    // MARK: Decisione

    func decide(_ decision: AdminAgentStudioDecision) async {
        guard canDecide else { return }
        deciding = decision
        defer { deciding = nil }
        let note = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await backend.api.call(AdminAgentStudioAPI.decide(approvalId: approvalId, decision, comment: note))
            comment = ""
            await load()
            await onDecided()
        } catch {
            actionError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }
}
