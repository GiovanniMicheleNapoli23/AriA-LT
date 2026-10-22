//
//  AdminWorkOrderCostExtraFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un costo aggiuntivo nuovo (POST /v1/work-orders/{id}/additional-costs): descrizione, importo e categoria.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderCostExtraFormViewModel: Identifiable {
    let orderId: String
    let backend: AriaBackend
    private let onSaved: () async -> Void

    var description = ""
    var value = ""
    var category: AdminWorkOrderCostCategory = .other

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(orderId: String, backend: AriaBackend, onSaved: @escaping () async -> Void) {
        self.orderId = orderId
        self.backend = backend
        self.onSaved = onSaved
    }

    private var trimmedDescription: String { description.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var amount: Double? { AdminWorkOrderCostFormat.number(value) }

    var validationMessage: String? {
        if trimmedDescription.isEmpty { return String(localized: "Add a description.") }
        if (amount ?? 0) <= 0 { return String(localized: "The amount must be greater than zero.") }
        return nil
    }

    var canSave: Bool { validationMessage == nil && !isSaving }

    var hasChanges: Bool { !trimmedDescription.isEmpty || !AdminWorkOrderCostFormat.isBlank(value) }

    var currencyCode: String { AdminWorkOrderCostFormat.currencyCode }

    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let body = AdminWorkOrderCostExtraCreate(description: trimmedDescription, value: amount, costCategory: category.rawValue)
        do {
            try await AdminWorkOrdersAPI(api: backend.api).addAdditionalCost(orderId, body)
            await onSaved()
            return true
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
            return false
        }
    }
}
