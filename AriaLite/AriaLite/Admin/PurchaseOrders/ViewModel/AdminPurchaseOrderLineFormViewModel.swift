//
//  AdminPurchaseOrderLineFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo per aggiungere una riga a un ordine (POST /v1/purchase-orders/{id}/lines): un ricambio scelto
//  dall'elenco dello stabilimento (compila codice e costo unitario) oppure un codice scritto a mano, la
//  quantità (obbligatoria, maggiore di 0), il costo unitario (facoltativo, 0 o più) e le note.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPurchaseOrderLineFormViewModel: Identifiable {
    let id = UUID()
    let parts: AdminPurchaseOrderLineParts
    private let backend: AriaBackend
    private let orderId: String
    private let plantId: String?
    /// Chiamato con la riga creata, prima di chiudere il modulo: il dettaglio la aggiunge e rilegge l'ordine.
    private let onAdded: @MainActor (AdminPurchaseOrderLine) async -> Void

    private(set) var selectedPart: AdminSparePart?
    /// Se si scrive un codice diverso da quello del ricambio scelto, il ricambio si deseleziona.
    var partCode = "" {
        didSet {
            if let selectedPart, partCode != selectedPart.code { self.selectedPart = nil }
        }
    }
    var quantity = ""
    var unitCost = ""
    var notes = ""
    var searchText = ""

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(orderId: String, plantId: String?, parts: AdminPurchaseOrderLineParts, backend: AriaBackend,
         onAdded: @escaping @MainActor (AdminPurchaseOrderLine) async -> Void) {
        self.orderId = orderId
        self.plantId = plantId
        self.parts = parts
        self.backend = backend
        self.onAdded = onAdded
    }

    // MARK: - Ricambi

    var currencyCode: String { AdminPurchaseOrderDetailFormat.currencyCode }

    var filteredParts: [AdminSparePart] { parts.matching(searchText) }

    func loadParts() async { await parts.loadIfNeeded(plantId: plantId) }

    /// Sceglie il ricambio: compila il codice e, se il ricambio ha un prezzo, il costo unitario.
    func select(_ part: AdminSparePart) {
        selectedPart = part
        partCode = part.code
        if let price = part.unitPrice { unitCost = Self.numberText(price) }
        errorMessage = nil
    }

    func clearSelection() {
        selectedPart = nil
        partCode = ""
    }

    /// "Nome · codice" del ricambio scelto, per la riga del modulo.
    var selectedPartTitle: String? {
        guard let selectedPart else { return nil }
        return selectedPart.name.isEmpty ? selectedPart.code : selectedPart.name
    }

    // MARK: - Controlli

    private var trimmedCode: String { partCode.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsedQuantity: Double? { Self.parseNumber(quantity) }

    /// Il costo è facoltativo: campo vuoto è `.none`; un testo non numerico o negativo è `.invalid`.
    private var unitCostResult: UnitCost {
        let text = unitCost.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return .none }
        guard let value = Self.parseNumber(text), value >= 0 else { return .invalid }
        return .value(value)
    }

    private enum UnitCost {
        case none, invalid
        case value(Double)
    }

    var quantityError: String? {
        let text = quantity.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        guard let value = parsedQuantity, value > 0 else { return String(localized: "Enter a quantity greater than 0.") }
        return nil
    }

    var unitCostError: String? {
        if case .invalid = unitCostResult { return String(localized: "Enter a cost of 0 or more, or leave it empty.") }
        return nil
    }

    var canSave: Bool {
        guard !isSaving, selectedPart != nil || !trimmedCode.isEmpty else { return false }
        guard let value = parsedQuantity, value > 0 else { return false }
        return unitCostError == nil
    }

    /// C'è un ricambio scelto o un codice scritto: una riga deve identificarne uno.
    var hasPart: Bool { selectedPart != nil || !trimmedCode.isEmpty }

    // MARK: - Salvataggio

    /// `true` se la riga è stata aggiunta e il modulo si può chiudere.
    func save() async -> Bool {
        guard canSave, let quantity = parsedQuantity else { return false }
        var unitCostValue: Double?
        if case .value(let value) = unitCostResult { unitCostValue = value }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = AdminPurchaseOrderLineCreate(
            partId: selectedPart?.id,
            partCode: trimmedCode.isEmpty ? nil : trimmedCode,
            quantity: quantity,
            unitCost: unitCostValue,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes)
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let line = try await AdminPurchaseOrdersAPI(api: backend.api).addLine(orderId: orderId, body)
            await onAdded(line)
            return true
        } catch {
            if let failure = AdminPurchaseOrdersFailure.from(error, action: .write, backend: backend) {
                errorMessage = failure.message
            }
            return false
        }
    }

    // MARK: - Numeri

    /// Accetta la virgola come separatore decimale; rifiuta NaN e infiniti.
    nonisolated static func parseNumber(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    nonisolated static func numberText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...4)).grouping(.never))
    }
}
