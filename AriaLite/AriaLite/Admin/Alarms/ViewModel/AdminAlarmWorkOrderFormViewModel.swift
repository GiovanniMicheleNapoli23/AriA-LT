//
//  AdminAlarmWorkOrderFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "Create work order" dalla diagnosi: titolo, descrizione, priorità, stabilimento e asset
//  precompilati dall'ordine suggerito (o dalla diagnosi), da controllare e confermare. I passi di
//  riparazione possono diventare la procedura dell'ordine. Crea con POST /v1/work-orders.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAlarmWorkOrderFormViewModel: Identifiable {
    private let alarm: AdminAlarm
    private let diagnosis: AdminAlarmDiagnosis
    private let backend: AriaBackend
    private let onCreated: (AdminAlarmCreatedWorkOrder) -> Void

    // MARK: - Campi

    var title: String
    var details: String
    /// `high`, `medium` o `low` (WorkOrderPriority).
    var priority: String
    var plantId: String?
    var assetTag: String
    var includesSteps: Bool

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(alarm: AdminAlarm, diagnosis: AdminAlarmDiagnosis, backend: AriaBackend,
         onCreated: @escaping (AdminAlarmCreatedWorkOrder) -> Void) {
        self.alarm = alarm
        self.diagnosis = diagnosis
        self.backend = backend
        self.onCreated = onCreated
        let suggested = diagnosis.suggestedWorkOrder
        title = suggested?.title ?? String(localized: "Fix alarm \(alarm.code)")
        details = suggested?.description ?? diagnosis.rootCause
        priority = Self.priority(suggested: suggested?.priority, severity: diagnosis.severityKey)
        plantId = backend.activePlantId ?? backend.plants.first?.id
        assetTag = suggested?.assetTag ?? alarm.assetTag ?? ""
        includesSteps = !diagnosis.repairSteps.isEmpty
    }

    /// La priorità dell'ordine suggerito se è valida, altrimenti quella che segue la gravità.
    private static func priority(suggested: String?, severity: String) -> String {
        if let suggested, ["high", "medium", "low"].contains(suggested) { return suggested }
        switch severity {
        case "critical", "high": return "high"
        case "low", "minor": return "low"
        default: return "medium"
        }
    }

    // MARK: - Presentazione

    var plants: [AriaPlant] { backend.plants }

    var priorityOptions: [(key: String, label: String)] {
        [("high", String(localized: "High")),
         ("medium", String(localized: "Medium")),
         ("low", String(localized: "Low"))]
    }

    var stepCount: Int { diagnosis.repairSteps.count }

    var canCreate: Bool {
        !isSaving && plantId != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Azioni

    private func optional(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// `true` se creato: il foglio si chiude.
    func create() async -> Bool {
        guard canCreate, let plantId else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let suggested = diagnosis.suggestedWorkOrder
        let steps = includesSteps ? diagnosis.repairSteps.map { step in
            [step.title, step.detail].compactMap { $0 }.joined(separator: ": ")
        } : []
        let body = AdminAlarmWorkOrderCreate(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            plantId: plantId,
            priority: priority,
            category: suggested?.category,
            assetTag: optional(assetTag),
            alarmCode: alarm.code,
            description: optional(details),
            estimatedDurationMin: suggested?.estimatedDurationMin,
            checklistData: AdminAlarmWorkOrderCreate.checklistText(steps: steps))
        do {
            let created = try await AdminAlarmsAPI(api: backend.api).createWorkOrder(body)
            onCreated(created)
            return true
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .workOrder, backend: backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}
