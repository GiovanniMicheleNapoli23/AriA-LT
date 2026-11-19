//
//  AdminMaintenanceDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un piano, come /maintenance/{id} della web: scheda del piano (GET /v1/maintenance-plans/{id}),
//  ordini di lavoro generati (GET /v1/work-orders, filtrati per piano qui), allegati e storico (figli).
//  Il piano della lista si mostra subito; quello del server lo sostituisce appena arriva. Le decisioni di
//  revisione (Approve, Unapprove, Reject, Back to draft) si prendono da qui in ogni stato (PATCH del solo
//  `status`), quelle che il ruolo permette.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AdminMaintenanceDetailViewModel {
    let backend: AriaBackend
    private(set) var plan: AdminMaintenancePlan
    /// Allegati e storico: senza id del server non c'è niente da chiedere.
    let files: AdminMaintenanceFilesViewModel?
    private let historyModel: AdminMaintenanceHistoryViewModel?
    /// Lo storico c'è solo se il ruolo ha `audit_log`: senza, la scheda non si mostra e la rotta non si chiama.
    var history: AdminMaintenanceHistoryViewModel? { backend.rights.has(.auditLog) ? historyModel : nil }
    /// Gli ordini generati sono ordini di lavoro: servono `work_orders`.
    var showsWorkOrders: Bool { backend.rights.has(.workOrders) }

    private(set) var workOrders: [AdminMaintenanceWorkOrder] = []
    private(set) var workOrdersError: String?
    private(set) var planError: String?
    /// La decisione di revisione in corso e l'errore dell'ultima.
    private(set) var reviewing: AdminReviewAction?
    private(set) var reviewError: String?
    /// La decisione che aspetta la conferma (Reject, Unapprove).
    var confirmingReview: AdminReviewAction?
    var isConfirmingReview: Bool {
        get { confirmingReview != nil }
        set { if !newValue { confirmingReview = nil } }
    }
    private(set) var hasLoaded = false
    private(set) var isLoading = false

    /// Avvisa la lista che il piano è cambiato.
    private let onChange: (AdminMaintenancePlan) -> Void
    /// Avvisa la lista che il piano è stato eliminato.
    private let onDelete: (AdminMaintenancePlan) -> Void

    init(backend: AriaBackend, plan: AdminMaintenancePlan, onChange: @escaping (AdminMaintenancePlan) -> Void,
         onDelete: @escaping (AdminMaintenancePlan) -> Void = { _ in }) {
        self.backend = backend
        self.plan = plan
        self.onChange = onChange
        self.onDelete = onDelete
        files = plan.serverId.map { AdminMaintenanceFilesViewModel(planId: $0, backend: backend) }
        historyModel = plan.serverId.map { AdminMaintenanceHistoryViewModel(planId: $0, backend: backend) }
    }

    /// Modifica e AI hanno bisogno dell'id del server.
    var canEdit: Bool { plan.serverId != nil }

    // MARK: Revisione

    private var storedStatus: String { plan.status ?? AdminMaintenanceStatus.draft.rawValue }

    var reviewStage: AdminReviewStage { AdminReviewStage(stored: storedStatus) }

    /// Le decisioni possibili ora (restano mentre una è in corso, ferme): nessuna senza id del server, né mentre
    /// l'eliminazione è in corso.
    var reviewActions: [AdminReviewAction] {
        guard canEdit, !isDeleting else { return [] }
        return AdminReviewAction.available(from: storedStatus, in: .maintenance, rights: backend.rights)
    }

    var reviewMessage: LocalizedStringKey {
        switch reviewStage {
        case .pending: "Approve this plan to make it active, or reject it if it isn't right."
        case .approved: "In use. Unapprove sends it back to draft; Reject takes it out of use."
        case .rejected: "Not in use. Back to draft reopens it for review; Approve puts it back in use."
        }
    }

    /// La barra delle decisioni: almeno una decisione, o una in corso.
    var showsReview: Bool { !reviewActions.isEmpty || reviewing != nil }

    /// Il riquadro di stato solo per un piano da rivedere: approvato o rifiutato lo dice già la pastiglia
    /// dell'intestazione, e le decisioni restano nella barra.
    var showsReviewNotice: Bool { showsReview && reviewStage == .pending }

    /// Reject e Unapprove chiedono conferma; le altre partono subito.
    func requestReview(_ action: AdminReviewAction) {
        if action.needsConfirmation {
            confirmingReview = action
        } else {
            Task { await review(action) }
        }
    }

    func review(_ action: AdminReviewAction) async {
        guard reviewing == nil, reviewActions.contains(action), let id = plan.serverId else { return }
        reviewing = action
        reviewError = nil
        defer { reviewing = nil }
        var changes = AdminPatchBody()
        changes.text("status", action.target, was: plan.status)
        do {
            let saved = try await backend.api.call(AdminMaintenanceAPI.update(id: id, changes))
            planSaved(saved)
        } catch {
            reviewError = AdminMaintenanceFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Eliminazione

    private(set) var isDeleting = false
    /// "Eliminare questo piano?" (conferma).
    var showsDeleteConfirmation = false
    /// Errore dell'eliminazione (alert).
    var deleteError: String?
    var isShowingDeleteError: Bool {
        get { deleteError != nil }
        set { if !newValue { deleteError = nil } }
    }

    /// Il cestino c'è solo con l'id del server e se il ruolo ha quello che servirebbe a rifiutarlo.
    var canDelete: Bool {
        plan.serverId != nil && reviewing == nil
            && backend.rights.canDelete(stored: plan.status ?? AdminMaintenanceStatus.draft.rawValue, in: .maintenance)
    }

    /// `true` se eliminato: la schermata si chiude.
    func delete() async -> Bool {
        guard canDelete, !isDeleting, let id = plan.serverId else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            _ = try await backend.api.call(AdminMaintenanceAPI.delete(id: id))
        } catch {
            if let message = AdminMaintenanceFailure.message(for: error, backend: backend) { deleteError = message }
            return false
        }
        onDelete(plan)
        return true
    }

    // MARK: Caricamento

    /// Scheda e ordini insieme; ciò che c'è a schermo resta finché arriva il nuovo.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        async let fresh: Void = refreshPlan()
        async let orders: Void = loadWorkOrders()
        _ = await (fresh, orders)
        hasLoaded = true
    }

    /// Il pull-to-refresh: anche allegati e storico.
    func reloadAll() async {
        async let main: Void = load()
        async let attachments: Void = reloadFiles()
        async let audit: Void = reloadHistory()
        _ = await (main, attachments, audit)
    }

    private func reloadFiles() async { await files?.load() }
    private func reloadHistory() async { await history?.load() }

    private func refreshPlan() async {
        guard let id = plan.serverId else { return }
        do {
            let fresh = try await backend.api.call(AdminMaintenanceAPI.plan(id: id))
            plan = fresh
            planError = nil
            onChange(fresh)
        } catch {
            if let message = AdminMaintenanceFailure.message(for: error, backend: backend) { planError = message }
        }
    }

    private func loadWorkOrders() async {
        guard let id = plan.serverId, showsWorkOrders else { return }
        do {
            let rows = try await backend.api.call(AdminMaintenanceAPI.workOrders(assetTag: plan.assetTag, plantId: plan.plantId))
            workOrders = rows.items
                .filter { $0.maintenancePlanId == id }
                .sorted { ($0.displayDate ?? .distantPast) > ($1.displayDate ?? .distantPast) }
            workOrdersError = nil
        } catch {
            if let message = AdminMaintenanceFailure.message(for: error, backend: backend) { workOrdersError = message }
        }
    }

    // MARK: Dopo una modifica

    func planSaved(_ saved: AdminMaintenancePlan) {
        plan = saved
        planError = nil
        onChange(saved)
        Task { await loadWorkOrders() }
    }

    func makeForm() -> AdminMaintenanceFormViewModel {
        AdminMaintenanceFormViewModel(backend: backend, editing: plan)
    }

    func makeImproveViewModel() -> AdminMaintenanceImproveViewModel {
        AdminMaintenanceImproveViewModel(backend: backend, plan: plan) { [weak self] in self?.planSaved($0) }
    }

    // MARK: Schede

    var plantName: String? { plan.plantId.flatMap { id in backend.plants.first { $0.id == id }?.name } }

    /// La riga accanto alle pastiglie: frequenza, asset, zona, stabilimento e categoria.
    var summaryLine: String {
        AdminMaintenanceFormat.joined([AdminMaintenanceFormat.schedule(plan), plan.assetTag, plan.zone, plantName, plan.category])
    }

    /// Le date e gli altri dati della programmazione, una riga per dato: la scadenza per prima
    /// (la frequenza è già nella riga di sintesi).
    var scheduleRows: [AdminMaintenanceScheduleRow] {
        var rows: [AdminMaintenanceScheduleRow] = []
        func add(_ title: String, _ value: String) { rows.append(AdminMaintenanceScheduleRow(title: title, value: value)) }
        if let due = plan.nextDueAt {
            rows.append(AdminMaintenanceScheduleRow(
                title: String(localized: "Next due"),
                value: "\(AdminMaintenanceFormat.date(due)) · \(AdminMaintenanceFormat.relative(due))", dueState: plan.dueState))
        }
        if let done = plan.lastDoneAt { add(String(localized: "Last done"), AdminMaintenanceFormat.date(done)) }
        if let minutes = plan.estimatedDurationMin {
            add(String(localized: "Estimated duration"), AdminMaintenanceFormat.duration(minutes: minutes))
        }
        if !plan.daysOfWeek.isEmpty {
            let days = AdminMaintenanceWeekday.allCases.map(\.rawValue).filter(plan.daysOfWeek.map { $0.lowercased() }.contains)
            add(String(localized: "Days"), (days.isEmpty ? plan.daysOfWeek : days).map(AdminMaintenanceWeekday.shortLabel(for:))
                .joined(separator: ", "))
        }
        if let start = plan.startsOn { add(String(localized: "Starts on"), AdminMaintenanceFormat.date(start)) }
        if let end = plan.endsOn { add(String(localized: "Ends on"), AdminMaintenanceFormat.date(end)) }
        if let recurrence = plan.recurrenceType { add(String(localized: "Recurrence"), recurrence) }
        return rows
    }

    /// Scheda tecnica: quello che l'intestazione non dice già (asset, luogo e stato sono lassù).
    var detailFields: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        if !plan.relatedAssetTags.isEmpty { add(String(localized: "Related assets"), plan.relatedAssetTags.joined(separator: ", ")) }
        add(String(localized: "Confidence"), plan.confidence.map { $0.formatted(.percent.precision(.fractionLength(0))) })
        add(String(localized: "Created"), plan.createdAt.map(AdminMaintenanceFormat.date))
        add(String(localized: "Updated"), plan.updatedAt.map(AdminMaintenanceFormat.date))
        return rows
    }
}
