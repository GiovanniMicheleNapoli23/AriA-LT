//
//  AdminMaintenanceDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un piano, come /maintenance/{id} della web: scheda del piano (GET /v1/maintenance-plans/{id}),
//  ordini di lavoro generati (GET /v1/work-orders, filtrati per piano qui), allegati e storico (figli).
//  Il piano della lista si mostra subito; quello del server lo sostituisce appena arriva.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMaintenanceDetailViewModel {
    let backend: AriaBackend
    private(set) var plan: AdminMaintenancePlan
    /// Allegati e storico: senza id del server non c'è niente da chiedere.
    let files: AdminMaintenanceFilesViewModel?
    let history: AdminMaintenanceHistoryViewModel?

    private(set) var workOrders: [AdminMaintenanceWorkOrder] = []
    private(set) var workOrdersError: String?
    private(set) var planError: String?
    private(set) var hasLoaded = false
    private(set) var isLoading = false

    /// Avvisa la lista che il piano è cambiato.
    private let onChange: (AdminMaintenancePlan) -> Void

    init(backend: AriaBackend, plan: AdminMaintenancePlan, onChange: @escaping (AdminMaintenancePlan) -> Void) {
        self.backend = backend
        self.plan = plan
        self.onChange = onChange
        files = plan.serverId.map { AdminMaintenanceFilesViewModel(planId: $0, backend: backend) }
        history = plan.serverId.map { AdminMaintenanceHistoryViewModel(planId: $0, backend: backend) }
    }

    /// Modifica e AI hanno bisogno dell'id del server.
    var canEdit: Bool { plan.serverId != nil }

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
        guard let id = plan.serverId else { return }
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

    /// Dove si trova: asset, zona e stabilimento in una riga.
    var placeLine: String {
        AdminMaintenanceFormat.joined([plan.zone, plantName, plan.category])
    }

    var dueText: String? {
        guard let due = plan.nextDueAt else { return nil }
        return "\(AdminMaintenanceFormat.date(due)) · \(AdminMaintenanceFormat.relative(due))"
    }

    /// Quando e quanto spesso: la scheda "Schedule".
    var scheduleFields: [AdminAssetField] {
        var rows = [AdminAssetField(title: String(localized: "Frequency"), value: AdminMaintenanceFormat.schedule(plan))]
        if let dueText { rows.append(AdminAssetField(title: String(localized: "Next due"), value: dueText)) }
        if let done = plan.lastDoneAt {
            rows.append(AdminAssetField(title: String(localized: "Last done"), value: AdminMaintenanceFormat.date(done)))
        }
        if !plan.daysOfWeek.isEmpty {
            let days = AdminMaintenanceWeekday.allCases.map(\.rawValue).filter(plan.daysOfWeek.map { $0.lowercased() }.contains)
            rows.append(AdminAssetField(title: String(localized: "Days"),
                                        value: (days.isEmpty ? plan.daysOfWeek : days)
                                            .map(AdminMaintenanceWeekday.shortLabel(for:)).joined(separator: ", ")))
        }
        if let minutes = plan.estimatedDurationMin {
            rows.append(AdminAssetField(title: String(localized: "Estimated duration"),
                                        value: AdminMaintenanceFormat.duration(minutes: minutes)))
        }
        if let start = plan.startsOn {
            rows.append(AdminAssetField(title: String(localized: "Starts on"), value: AdminMaintenanceFormat.date(start)))
        }
        if let end = plan.endsOn {
            rows.append(AdminAssetField(title: String(localized: "Ends on"), value: AdminMaintenanceFormat.date(end)))
        }
        if let recurrence = plan.recurrenceType {
            rows.append(AdminAssetField(title: String(localized: "Recurrence"), value: recurrence))
        }
        return rows
    }

    /// Scheda tecnica: asset, luogo, stato e date del record.
    var detailFields: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Asset"), plan.assetTag)
        if !plan.relatedAssetTags.isEmpty { add(String(localized: "Related assets"), plan.relatedAssetTags.joined(separator: ", ")) }
        add(String(localized: "Plant"), plantName)
        add(String(localized: "Zone"), plan.zone)
        add(String(localized: "Category"), plan.category)
        add(String(localized: "Status"), plan.status.map(AdminMaintenanceStatus.label(for:)))
        add(String(localized: "Confidence"), plan.confidence.map { $0.formatted(.percent.precision(.fractionLength(0))) })
        add(String(localized: "Created"), plan.createdAt.map(AdminMaintenanceFormat.date))
        add(String(localized: "Updated"), plan.updatedAt.map(AdminMaintenanceFormat.date))
        return rows
    }
}
