//
//  AdminWorkOrderCostsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Costi di un ordine: manodopera (/labor), ricambi usati (/parts-used) e costi aggiuntivi (/additional-costs).
//  Le tre liste arrivano insieme, ognuna per conto suo: un 403 su una spegne solo la sua sezione.
//  Dopo ogni aggiunta, modifica o eliminazione la sezione si ricarica (le risposte non sono descritte).
//  I totali si calcolano qui: minuti per tariffa oraria, quantità per costo unitario, somma degli extra.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderCostsViewModel {
    let orderId: String
    let backend: AriaBackend
    /// Persone e ricambi da scegliere nei form.
    let catalog: AdminWorkOrderPartCatalog

    private(set) var labor: [AdminWorkOrderLaborEntry] = []
    private(set) var parts: [AdminWorkOrderPartUsage] = []
    private(set) var extras: [AdminWorkOrderCostExtra] = []

    private(set) var hasLoaded = false
    private(set) var isLoading = false
    /// Perché una sezione non si è caricata (403 compreso).
    private(set) var sectionErrors: [AdminWorkOrderCostKind: String] = [:]
    /// Sezioni che il ruolo non può leggere: niente pulsante per aggiungere.
    private(set) var forbidden: Set<AdminWorkOrderCostKind> = []
    /// Errore dell'ultima eliminazione.
    private(set) var errorMessage: String?
    private(set) var deletingIds: Set<String> = []

    /// I form aperti (sheet).
    var laborForm: AdminWorkOrderLaborFormViewModel?
    var partForm: AdminWorkOrderPartFormViewModel?
    var extraForm: AdminWorkOrderCostExtraFormViewModel?
    /// La riga da eliminare, in attesa di conferma.
    var pendingDelete: AdminWorkOrderCostRowItem?

    init(orderId: String, backend: AriaBackend) {
        self.orderId = orderId
        self.backend = backend
        catalog = AdminWorkOrderPartCatalog(backend: backend)
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    // MARK: Caricamento

    /// Alla prima apertura della scheda; cambiando scheda e tornando i dati restano.
    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await load()
    }

    /// Le tre sezioni da capo (anche a ogni aggiornamento del dettaglio).
    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let labor: Void = reload(.labor)
        async let parts: Void = reload(.parts)
        async let extras: Void = reload(.extra)
        _ = await (labor, parts, extras)
        hasLoaded = true
    }

    private func reload(_ kind: AdminWorkOrderCostKind) async {
        let api = api, id = orderId
        do {
            switch kind {
            case .labor: labor = try await api.labor(id).sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
            case .parts: parts = try await api.partsUsed(id)
            case .extra: extras = try await api.additionalCosts(id)
            }
            sectionErrors[kind] = nil
            forbidden.remove(kind)
        } catch {
            guard let message = AdminWorkOrderFailure.message(for: error, backend: backend) else { return }
            sectionErrors[kind] = message
            if AdminWorkOrderFailure.isForbidden(error) { forbidden.insert(kind) }
        }
    }

    // MARK: Righe

    func rows(_ kind: AdminWorkOrderCostKind) -> [AdminWorkOrderCostRowItem] {
        switch kind {
        case .labor: labor.map(laborRow)
        case .parts: parts.map(partRow)
        case .extra: extras.map(extraRow)
        }
    }

    private func laborRow(_ entry: AdminWorkOrderLaborEntry) -> AdminWorkOrderCostRowItem {
        let minutes = entry.durationMin.map { AdminWorkOrderFormat.duration(minutes: Int($0.rounded())) }
        let rate = entry.hourlyRate.map { String(localized: "\(AdminWorkOrderCostFormat.money($0))/h") }
        return AdminWorkOrderCostRowItem(
            kind: .labor, entryId: entry.id,
            title: entry.worker ?? String(localized: "Unknown worker"),
            subtitle: AdminWorkOrderFormat.joined([entry.startedAt.map(AdminWorkOrderFormat.shortDate), minutes, rate]),
            amount: AdminWorkOrderCostFormat.money(entry.cost), isEditable: false)
    }

    private func partRow(_ usage: AdminWorkOrderPartUsage) -> AdminWorkOrderCostRowItem {
        let quantity = usage.quantity.map { AdminWorkOrderFormat.joined([AdminWorkOrderCostFormat.quantity($0), usage.unit]) }
        let unitCost = usage.unitCost.map { String(localized: "× \(AdminWorkOrderCostFormat.money($0))") }
        let title = usage.partName ?? usage.partCode ?? String(localized: "Part")
        return AdminWorkOrderCostRowItem(
            kind: .parts, entryId: usage.id, title: title,
            subtitle: AdminWorkOrderFormat.joined([usage.partName == nil ? nil : usage.partCode,
                                                   AdminWorkOrderFormat.joined([quantity, unitCost])]),
            amount: AdminWorkOrderCostFormat.money(usage.cost), isEditable: true)
    }

    private func extraRow(_ extra: AdminWorkOrderCostExtra) -> AdminWorkOrderCostRowItem {
        AdminWorkOrderCostRowItem(
            kind: .extra, entryId: extra.id,
            title: extra.description ?? String(localized: "Additional cost"),
            subtitle: AdminWorkOrderFormat.joined([AdminWorkOrderCostCategory.label(for: extra.costCategory),
                                                   extra.createdAt.map(AdminWorkOrderFormat.shortDate)]),
            amount: AdminWorkOrderCostFormat.money(extra.value ?? 0), isEditable: false)
    }

    func subtotal(_ kind: AdminWorkOrderCostKind) -> String {
        AdminWorkOrderCostFormat.money(sum(kind))
    }

    private func sum(_ kind: AdminWorkOrderCostKind) -> Double {
        switch kind {
        case .labor: labor.reduce(0) { $0 + $1.cost }
        case .parts: parts.reduce(0) { $0 + $1.cost }
        case .extra: extras.reduce(0) { $0 + ($1.value ?? 0) }
        }
    }

    var totals: AdminWorkOrderCostTotals {
        let labor = sum(.labor), parts = sum(.parts), extra = sum(.extra)
        return AdminWorkOrderCostTotals(
            labor: AdminWorkOrderCostFormat.money(labor), parts: AdminWorkOrderCostFormat.money(parts),
            extra: AdminWorkOrderCostFormat.money(extra), total: AdminWorkOrderCostFormat.money(labor + parts + extra))
    }

    func canAdd(_ kind: AdminWorkOrderCostKind) -> Bool { !forbidden.contains(kind) }

    // MARK: Form

    func startAdding(_ kind: AdminWorkOrderCostKind) {
        errorMessage = nil
        let onSaved: () async -> Void = { [weak self] in await self?.reload(kind) }
        switch kind {
        case .labor:
            let lastRate = labor.first { $0.hourlyRate != nil }?.hourlyRate
            laborForm = AdminWorkOrderLaborFormViewModel(orderId: orderId, backend: backend, catalog: catalog,
                                                         lastRate: lastRate, onSaved: onSaved)
        case .parts:
            partForm = AdminWorkOrderPartFormViewModel(mode: .create, orderId: orderId, backend: backend,
                                                       catalog: catalog, onSaved: onSaved)
        case .extra:
            extraForm = AdminWorkOrderCostExtraFormViewModel(orderId: orderId, backend: backend, onSaved: onSaved)
        }
    }

    /// Toccare un ricambio usato apre la modifica di quantità e costo unitario.
    func startEditing(_ row: AdminWorkOrderCostRowItem) {
        guard row.isEditable, let usage = parts.first(where: { $0.id == row.entryId }) else { return }
        errorMessage = nil
        partForm = AdminWorkOrderPartFormViewModel(mode: .edit(usage), orderId: orderId, backend: backend, catalog: catalog) {
            [weak self] in await self?.reload(.parts)
        }
    }

    // MARK: Eliminazione

    func confirmDelete(_ row: AdminWorkOrderCostRowItem) { pendingDelete = row }

    var isConfirmingDelete: Bool {
        get { pendingDelete != nil }
        set { if !newValue { pendingDelete = nil } }
    }

    /// Riceve la riga dal dialogo: alla chiusura `pendingDelete` è già `nil`.
    func delete(_ row: AdminWorkOrderCostRowItem) async {
        pendingDelete = nil
        deletingIds.insert(row.id)
        errorMessage = nil
        defer { deletingIds.remove(row.id) }
        let api = api, id = orderId
        do {
            switch row.kind {
            case .labor: try await api.deleteLabor(id, entryId: row.entryId)
            case .parts: try await api.deletePartUsage(id, entryId: row.entryId)
            case .extra: try await api.deleteAdditionalCost(id, entryId: row.entryId)
            }
            remove(row)
            await reload(row.kind)
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    private func remove(_ row: AdminWorkOrderCostRowItem) {
        switch row.kind {
        case .labor: labor.removeAll { $0.id == row.entryId }
        case .parts: parts.removeAll { $0.id == row.entryId }
        case .extra: extras.removeAll { $0.id == row.entryId }
        }
    }
}
