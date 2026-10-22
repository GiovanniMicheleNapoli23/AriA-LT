//
//  AdminAlarmFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di modifica di un allarme (PATCH /v1/alarms/{id} con i soli campi cambiati; un campo
//  svuotato si manda come null). Il codice non si modifica. Cause e passi sono elenchi di righe.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAlarmFormViewModel: Identifiable {
    let alarm: AdminAlarm
    private let backend: AriaBackend
    /// L'allarme salvato, per chi ha aperto il modulo.
    private let onSaved: (AdminAlarm) -> Void

    // MARK: - Campi

    var description: String
    var statusKey: String
    var assetTag: String
    var category: String
    var zone: String
    var hmiPage: String
    var causes: [AdminAlarmListItem]
    var steps: [AdminAlarmListItem]

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(alarm: AdminAlarm, backend: AriaBackend, onSaved: @escaping (AdminAlarm) -> Void) {
        self.alarm = alarm
        self.backend = backend
        self.onSaved = onSaved
        description = alarm.description
        statusKey = alarm.statusKey
        assetTag = alarm.assetTag ?? ""
        category = alarm.category ?? ""
        zone = alarm.zone ?? ""
        hmiPage = alarm.hmiPage ?? ""
        causes = AdminAlarmListItem.items(alarm.typicalCauses)
        steps = AdminAlarmListItem.items(alarm.resolutionSteps)
    }

    // MARK: - Presentazione

    /// Gli stati fra cui scegliere; uno sconosciuto che l'allarme ha già resta nell'elenco.
    var statusOptions: [(key: String, label: String)] {
        var options = AdminAlarmStatus.allCases.map { (key: $0.rawValue, label: $0.label) }
        if AdminAlarmStatus(rawValue: alarm.statusKey) == nil { options.append((alarm.statusKey, alarm.statusLabel)) }
        return options
    }

    var canSave: Bool { !isSaving && hasChanges && !trimmed(description).isEmpty }

    /// Qualcosa è cambiato: chiudere con un trascinamento perderebbe le modifiche.
    var hasChanges: Bool { !patch.isEmpty }

    // MARK: - Lettura dei campi

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Il cambiamento di un testo facoltativo: assente se uguale, `null` se svuotato.
    private func change(_ text: String, was old: String?) -> String?? {
        let value = trimmed(text)
        guard value != (old ?? "") else { return nil }
        return .some(value.isEmpty ? nil : value)
    }

    private func change(_ items: [AdminAlarmListItem], was old: [String]) -> [String]?? {
        let lines = AdminAlarmListItem.lines(items)
        return lines == old ? nil : .some(lines)
    }

    /// Solo i campi diversi da quelli dell'allarme.
    private var patch: AdminAlarmUpdate {
        var update = AdminAlarmUpdate()
        let newDescription = trimmed(description)
        if newDescription != alarm.description { update.description = .some(newDescription) }
        if statusKey != alarm.statusKey { update.status = .some(statusKey) }
        update.assetTag = change(assetTag, was: alarm.assetTag)
        update.category = change(category, was: alarm.category)
        update.zone = change(zone, was: alarm.zone)
        update.hmiPage = change(hmiPage, was: alarm.hmiPage)
        update.typicalCauses = change(causes, was: alarm.typicalCauses)
        update.resolutionSteps = change(steps, was: alarm.resolutionSteps)
        return update
    }

    // MARK: - Azioni

    func addCause() { causes.append(AdminAlarmListItem()) }
    func addStep() { steps.append(AdminAlarmListItem()) }

    /// `true` se salvato: il foglio si chiude.
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let saved = try await AdminAlarmsAPI(api: backend.api).update(id: alarm.id, patch)
            onSaved(saved)
            return true
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}
