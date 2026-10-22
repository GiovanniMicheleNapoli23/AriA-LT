//
//  AdminWorkOrderLaborFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga di manodopera nuova (POST /v1/work-orders/{id}/labor): chi, da quando, quanti minuti e a che
//  tariffa oraria. La persona si sceglie dall'elenco degli utenti o si scrive a mano.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderLaborFormViewModel: Identifiable {
    let orderId: String
    let backend: AriaBackend
    let catalog: AdminWorkOrderPartCatalog
    private let onSaved: () async -> Void

    var worker = ""
    /// La persona scelta dall'elenco; scrivere un altro nome la toglie.
    private(set) var workerUserId: String?
    var startedAt = Date.now
    var minutes = ""
    var hourlyRate: String

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    /// `lastRate`: la tariffa dell'ultima riga dell'ordine, per non riscriverla ogni volta.
    init(orderId: String, backend: AriaBackend, catalog: AdminWorkOrderPartCatalog, lastRate: Double?,
         onSaved: @escaping () async -> Void) {
        self.orderId = orderId
        self.backend = backend
        self.catalog = catalog
        self.onSaved = onSaved
        hourlyRate = AdminWorkOrderCostFormat.editable(lastRate)
    }

    func loadChoices() async {
        await catalog.loadUsers()
    }

    // MARK: Persona

    var workerChoices: [AdminWorkOrderChoice] { catalog.userChoices }
    var workersUnavailable: Bool { catalog.usersUnavailable }

    var workerLabel: String {
        catalog.user(workerUserId)?.displayName ?? String(localized: "None")
    }

    func selectWorker(_ id: String?) {
        workerUserId = id
        if let user = catalog.user(id) { worker = user.displayName }
    }

    /// Il nome scritto a mano non è più quello della persona scelta.
    func workerTextChanged() {
        if let user = catalog.user(workerUserId), user.displayName != worker { workerUserId = nil }
    }

    // MARK: Controlli

    private var trimmedWorker: String { worker.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var durationValue: Double? { AdminWorkOrderCostFormat.number(minutes) }
    private var rateValue: Double? { AdminWorkOrderCostFormat.number(hourlyRate) }

    var validationMessage: String? {
        if trimmedWorker.isEmpty { return String(localized: "Add who did the work.") }
        if (durationValue ?? 0) <= 0 { return String(localized: "Enter the minutes worked.") }
        if !AdminWorkOrderCostFormat.isBlank(hourlyRate), (rateValue ?? -1) < 0 {
            return String(localized: "The hourly rate must be a number of zero or more.")
        }
        return nil
    }

    /// "Cost: € 45,00" mentre si scrive.
    var costPreview: String? {
        guard let duration = durationValue, duration > 0, let rate = rateValue, rate >= 0 else { return nil }
        return String(localized: "Cost: \(AdminWorkOrderCostFormat.money(duration / 60 * rate))")
    }

    var canSave: Bool { validationMessage == nil && !isSaving }

    var hasChanges: Bool { !trimmedWorker.isEmpty || !AdminWorkOrderCostFormat.isBlank(minutes) }

    // MARK: Salvataggio

    /// `true` se salvato: il form si chiude.
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let body = AdminWorkOrderLaborCreate(worker: trimmedWorker, startedAt: AdminWorkOrderWireDate.string(startedAt),
                                             durationMin: durationValue, hourlyRate: rateValue)
        do {
            try await AdminWorkOrdersAPI(api: backend.api).addLabor(orderId, body)
            await onSaved()
            return true
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
            return false
        }
    }
}
