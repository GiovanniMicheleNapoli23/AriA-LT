//
//  AdminWorkOrderPartFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ricambio usato nell'ordine: nuovo (POST /parts-used) o già registrato (PATCH quantità e costo
//  unitario). Il ricambio si sceglie dal magazzino dello stabilimento, che propone il prezzo unitario e
//  mostra la giacenza; senza elenco si scrive il codice.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderPartFormViewModel: Identifiable {
    enum Mode {
        case create
        case edit(AdminWorkOrderPartUsage)
    }

    let mode: Mode
    let orderId: String
    let backend: AriaBackend
    let catalog: AdminWorkOrderPartCatalog
    private let onSaved: () async -> Void

    /// Il ricambio scelto dal magazzino.
    private(set) var partId: String?
    /// Il codice scritto a mano quando l'elenco non c'è o il ricambio non è in elenco.
    var partCode = ""
    var quantity: String
    var unitCost: String
    private let original: (quantity: String, unitCost: String)

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(mode: Mode, orderId: String, backend: AriaBackend, catalog: AdminWorkOrderPartCatalog,
         onSaved: @escaping () async -> Void) {
        self.mode = mode
        self.orderId = orderId
        self.backend = backend
        self.catalog = catalog
        self.onSaved = onSaved
        let start: (quantity: String, unitCost: String) = switch mode {
        case .create: ("1", "")
        case .edit(let usage):
            (AdminWorkOrderCostFormat.editable(usage.quantity), AdminWorkOrderCostFormat.editable(usage.unitCost))
        }
        quantity = start.quantity
        unitCost = start.unitCost
        original = start
    }

    var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    var title: String { isCreating ? String(localized: "Add Part") : String(localized: "Edit Part") }

    func loadChoices() async {
        await catalog.loadParts()
    }

    // MARK: Ricambio

    var partChoices: [AdminWorkOrderChoice] { catalog.partChoices }
    var partsUnavailable: Bool { catalog.partsUnavailable }
    var selectedPart: AdminWorkOrderPartOption? { catalog.part(partId) }

    var partLabel: String {
        switch mode {
        case .create:
            return selectedPart.map { AdminWorkOrderFormat.joined([$0.code, $0.name]) } ?? String(localized: "None")
        case .edit(let usage):
            let label = AdminWorkOrderFormat.joined([usage.partCode, usage.partName])
            return label.isEmpty ? String(localized: "Part") : label
        }
    }

    /// Giacenza del ricambio scelto (o di quello della riga in modifica, se è nell'elenco).
    var stockLabel: String? {
        let part: AdminWorkOrderPartOption? = switch mode {
        case .create: selectedPart
        case .edit(let usage): catalog.parts.first { $0.partId == usage.partId || $0.code == usage.partCode }
        }
        return part.flatMap(AdminWorkOrderCostFormat.stock(of:))
    }

    /// Scegliere un ricambio propone il suo prezzo come costo unitario.
    func selectPart(_ id: String?) {
        partId = id
        guard let part = catalog.part(id) else { return }
        partCode = ""
        if let price = part.unitPrice { unitCost = AdminWorkOrderCostFormat.editable(price) }
    }

    // MARK: Controlli

    private var quantityValue: Double? { AdminWorkOrderCostFormat.number(quantity) }
    private var unitCostValue: Double? { AdminWorkOrderCostFormat.number(unitCost) }
    private var trimmedCode: String { partCode.trimmingCharacters(in: .whitespacesAndNewlines) }

    var validationMessage: String? {
        if isCreating, selectedPart == nil, trimmedCode.isEmpty { return String(localized: "Choose a part or enter its code.") }
        if (quantityValue ?? 0) <= 0 { return String(localized: "The quantity must be greater than zero.") }
        if !AdminWorkOrderCostFormat.isBlank(unitCost), (unitCostValue ?? -1) < 0 {
            return String(localized: "The unit cost must be a number of zero or more.")
        }
        return nil
    }

    /// Più pezzi di quanti ce ne sono in magazzino: si avvisa, non si blocca.
    var stockWarning: String? {
        guard isCreating, let part = selectedPart, !part.nonStock, let stock = part.stockQuantity,
              let wanted = quantityValue, wanted > stock else { return nil }
        return String(localized: "Only \(AdminWorkOrderCostFormat.quantity(stock)) in stock.")
    }

    var linePreview: String? {
        guard let quantity = quantityValue, quantity > 0, let cost = unitCostValue, cost >= 0 else { return nil }
        return String(localized: "Line total: \(AdminWorkOrderCostFormat.money(quantity * cost))")
    }

    var hasChanges: Bool {
        isCreating ? (partId != nil || !trimmedCode.isEmpty) : (quantity != original.quantity || unitCost != original.unitCost)
    }

    var canSave: Bool { validationMessage == nil && !isSaving && (isCreating || hasChanges) }

    // MARK: Salvataggio

    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let api = AdminWorkOrdersAPI(api: backend.api)
        do {
            switch mode {
            case .create:
                let part = selectedPart
                try await api.addPartUsage(orderId, AdminWorkOrderPartUsageCreate(
                    partId: part?.partId, partCode: part?.code ?? trimmedCode,
                    quantity: quantityValue, unitCost: unitCostValue))
            case .edit(let usage):
                try await api.updatePartUsage(orderId, entryId: usage.id,
                                              AdminWorkOrderPartUsageUpdate(quantity: quantityValue, unitCost: unitCostValue))
            }
            await onSaved()
            return true
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
            return false
        }
    }
}
