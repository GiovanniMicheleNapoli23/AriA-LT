//
//  AdminScenarioClosureDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di una procedura chiusa senza riparazione: dove si è fermata, cosa si era fatto e trovato,
//  perché è stata chiusa e la decisione dell'admin. Sola lettura (la decisione si prende dalla web); c'è il report.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioClosureDetailViewModel {
    let closure: AdminScenarioClosure
    let report: AdminScenarioReportViewModel

    init(backend: AriaBackend, closure: AdminScenarioClosure) {
        self.closure = closure
        report = AdminScenarioReportViewModel(backend: backend, sessionId: closure.sessionId,
                                              episode: closure.episode ?? 1, title: closure.title,
                                              workOrderId: closure.workOrderId)
    }

    var statusLabel: String? { closure.status.map(AdminScenarioClosureStatus.label(for:)) }

    /// Dove e perché si è fermata.
    var closureFields: [AdminAssetField] {
        let c = closure
        var fields: [AdminAssetField] = []
        if let step = c.stepNumber {
            let value = c.closureStepTitle.map { String(localized: "Step \(step) — \($0)") } ?? String(localized: "Step \(step)")
            fields.append(.init(title: String(localized: "Stopped at"), value: value))
        }
        if let reason = c.closureReasonCode {
            fields.append(.init(title: String(localized: "Reason"), value: AdminScenarioLabel.humanized(reason)))
        }
        if let name = c.closedByName ?? c.closedBy { fields.append(.init(title: String(localized: "Closed by"), value: name)) }
        if let date = c.createdAt { fields.append(.init(title: String(localized: "Closed on"), value: AdminScenarioFormat.date(date))) }
        if let category = c.alarmCategory {
            fields.append(.init(title: String(localized: "Alarm category"), value: AdminScenarioLabel.humanized(category)))
        }
        if let episode = c.episode, episode > 1 {
            fields.append(.init(title: String(localized: "Procedure"), value: episode.formatted()))
        }
        return fields
    }

    /// Cosa è stato deciso, se qualcosa.
    var decisionFields: [AdminAssetField] {
        let c = closure
        var fields: [AdminAssetField] = []
        if let label = statusLabel { fields.append(.init(title: String(localized: "Status"), value: label)) }
        if let by = c.decidedBy { fields.append(.init(title: String(localized: "Decided by"), value: by)) }
        if let date = c.decidedAt { fields.append(.init(title: String(localized: "Decided on"), value: AdminScenarioFormat.date(date))) }
        if let name = c.assignedToName ?? c.assignedTo { fields.append(.init(title: String(localized: "Reassigned to"), value: name)) }
        if let by = c.readBy { fields.append(.init(title: String(localized: "Read by"), value: by)) }
        if let date = c.readAt { fields.append(.init(title: String(localized: "Read on"), value: AdminScenarioFormat.date(date))) }
        if let order = c.workOrderId { fields.append(.init(title: String(localized: "Work order"), value: order)) }
        return fields
    }

    var completedSteps: [String] { closure.completedSteps ?? [] }
    var findings: [String] { closure.findings ?? [] }
}
