//
//  AdminWorkOrderStepActions.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I passi della procedura modificati dall'admin, come il planner della web: la spunta di un passo
//  (PUT .../steps/{step_id} con `checked`), il risultato con la nota (PUT con `status` e `note`), la cancellazione
//  di un risultato (DELETE) e la spunta di tutti i passi insieme (PUT .../steps). Dopo ogni modifica il dettaglio
//  si ricarica: il risultato sta sia nella procedura sia nei resoconti.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderStepActions {
    private let orderId: String
    private let backend: AriaBackend
    /// Rilegge ordine e resoconti.
    @ObservationIgnored var reload: () async -> Void = {}

    /// Passi con una richiesta in volo.
    private(set) var busyStepIds: Set<String> = []
    /// "Check all" o "Reset all checks" in corso.
    private(set) var isBulkBusy = false
    var errorMessage: String?
    /// Il foglio del risultato con la nota.
    var report: AdminWorkOrderStepReportViewModel?
    /// Il passo di cui cancellare il risultato, in attesa di conferma.
    var clearing: AdminWorkOrderStepRowItem?
    var isConfirmingReset = false

    init(orderId: String, backend: AriaBackend) {
        self.orderId = orderId
        self.backend = backend
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    func isBusy(_ step: AdminWorkOrderStepRowItem) -> Bool { isBulkBusy || busyStepIds.contains(step.id) }

    var isConfirmingClear: Bool {
        get { clearing != nil }
        set { if !newValue { clearing = nil } }
    }

    // MARK: Un passo

    /// La spunta: un passo fatto si toglie, gli altri diventano fatti.
    func toggle(_ step: AdminWorkOrderStepRowItem) {
        let checked = step.status != .done
        run(step) { api, orderId in try await api.checkStep(orderId, step: step.id, checked: checked) }
    }

    func startReport(_ step: AdminWorkOrderStepRowItem, status: AdminWorkOrderStepStatus) {
        report = AdminWorkOrderStepReportViewModel(orderId: orderId, step: step, status: status, backend: backend) { [weak self] in
            await self?.reload()
        }
    }

    func confirmClear(_ step: AdminWorkOrderStepRowItem) { clearing = step }

    func clear() {
        guard let step = clearing else { return }
        clearing = nil
        run(step) { api, orderId in try await api.clearStep(orderId, step: step.id) }
    }

    private func run(_ step: AdminWorkOrderStepRowItem, _ call: @escaping (AdminWorkOrdersAPI, String) async throws -> Void) {
        guard !isBusy(step) else { return }
        busyStepIds.insert(step.id)
        errorMessage = nil
        let api = api, orderId = orderId
        Task {
            defer { busyStepIds.remove(step.id) }
            do {
                try await call(api, orderId)
            } catch {
                errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
            }
            await reload()
        }
    }

    // MARK: Tutti i passi

    func checkAll() async { await setAll(checked: true) }

    func confirmReset() { isConfirmingReset = true }

    func resetAll() async { await setAll(checked: false) }

    private func setAll(checked: Bool) async {
        guard !isBulkBusy else { return }
        isBulkBusy = true
        errorMessage = nil
        defer { isBulkBusy = false }
        do {
            try await api.checkAllSteps(orderId, checked: checked)
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
        await reload()
    }
}

/// Il foglio del risultato di un passo: fatto o non fatto, con la nota (obbligatoria per "non fatto").
@MainActor
@Observable
final class AdminWorkOrderStepReportViewModel: Identifiable {
    let orderId: String
    let step: AdminWorkOrderStepRowItem
    private let backend: AriaBackend
    private let onSaved: () async -> Void

    var status: AdminWorkOrderStepStatus
    var note: String
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var isDone = false

    static let maxLength = 2000

    init(orderId: String, step: AdminWorkOrderStepRowItem, status: AdminWorkOrderStepStatus, backend: AriaBackend,
         onSaved: @escaping () async -> Void) {
        self.orderId = orderId
        self.step = step
        self.status = status == .unknown ? .done : status
        self.backend = backend
        self.onSaved = onSaved
        note = step.note ?? ""
    }

    var id: String { step.id }

    private var trimmed: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// "Non fatto" vuole il perché.
    var isNoteRequired: Bool { status == .notDone }

    var isTooLong: Bool { trimmed.count > Self.maxLength }

    var canSave: Bool { !isSaving && !isTooLong && (!isNoteRequired || !trimmed.isEmpty) }

    func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await AdminWorkOrdersAPI(api: backend.api)
                .reportStep(orderId, step: step.id, status: status, note: trimmed.isEmpty ? nil : trimmed)
            isDone = true
            await onSaved()
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }
}
