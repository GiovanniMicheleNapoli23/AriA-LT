//
//  AdminWorkOrderFormViewModel+Steps.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La creazione a passi: cosa manca in ogni pagina, avanti e indietro, e il riepilogo dell'ultima.
//  Lo scorrimento tra le pagine è libero (TabView a pagine): "Next" si ferma se la pagina ha un problema,
//  e il riepilogo elenca quello che manca ancora; il salvataggio resta legato a `canSave`.
//

import Foundation

extension AdminWorkOrderFormViewModel {
    var steps: [AdminWorkOrderFormStep] { AdminWorkOrderFormStep.allCases }

    var isFirstStep: Bool { step == steps.first }
    var isLastStep: Bool { step == steps.last }

    /// Cosa impedisce di andare avanti da una pagina; `nil` se è a posto.
    func issue(in step: AdminWorkOrderFormStep) -> String? {
        switch step {
        case .details:
            trimmedTitle.isEmpty ? String(localized: "Add a title.") : nil
        case .location:
            draft.plantId == nil ? String(localized: "Choose a plant.") : nil
        case .assignment:
            minutesAreValid ? nil : String(localized: "The estimated duration must be a whole number of minutes.")
        case .classification, .review:
            nil
        }
    }

    var currentIssue: String? { issue(in: step) }

    var canAdvance: Bool { !isLastStep && currentIssue == nil }

    func advance() {
        guard canAdvance, let next = AdminWorkOrderFormStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func goBack() {
        guard let previous = AdminWorkOrderFormStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func go(to step: AdminWorkOrderFormStep) { self.step = step }

    // MARK: Riepilogo

    var summary: [AdminWorkOrderFormSummaryGroup] {
        steps.filter { $0 != .review }.map { step in
            AdminWorkOrderFormSummaryGroup(step: step, rows: summaryRows(for: step), issue: issue(in: step))
        }
    }

    private func summaryRows(for step: AdminWorkOrderFormStep) -> [AdminWorkOrderFormSummaryRow] {
        let d = draft
        var rows: [AdminWorkOrderFormSummaryRow] = []
        func add(_ label: String, _ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
            rows.append(AdminWorkOrderFormSummaryRow(label: label, value: value))
        }
        switch step {
        case .details:
            add(String(localized: "Title"), trimmedTitle)
            add(String(localized: "Description"), d.description)
        case .classification:
            add(String(localized: "Priority"), d.priority.localized)
            add(String(localized: "Type"), d.type.localized)
            add(String(localized: "Status"), d.status.localized)
            add(String(localized: "Category"), d.category)
        case .location:
            add(String(localized: "Plant"), d.plantId == nil ? nil : plantLabel)
            add(String(localized: "Asset"), d.assetTag == nil ? nil : assetLabel)
            add(String(localized: "Zone"), d.zone)
            add(String(localized: "Alarm code"), d.alarmCode)
        case .assignment:
            add(String(localized: "Assignee"), d.assignedUserId == nil ? nil : userLabel)
            add(String(localized: "Team"), d.teamId == nil ? nil : teamLabel)
            add(String(localized: "Requested by"), d.requestedBy)
            add(String(localized: "Scheduled"), d.hasScheduledDate ? Self.dateText(d.scheduledDate) : nil)
            add(String(localized: "Due"), d.hasDueDate ? Self.dateText(d.dueDate) : nil)
            add(String(localized: "Estimated duration"), minutes.map { AdminWorkOrderFormat.duration(minutes: $0) })
        case .review:
            break
        }
        return rows
    }

    private static func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
