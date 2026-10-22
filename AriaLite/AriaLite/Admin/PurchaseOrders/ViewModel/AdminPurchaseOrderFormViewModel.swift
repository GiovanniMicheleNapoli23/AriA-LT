//
//  AdminPurchaseOrderFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di un ordine di acquisto, per crearlo (POST /v1/purchase-orders) o modificarne la testata
//  (PATCH con i soli campi cambiati; un campo svuotato si manda come null). Le date si mandano "YYYY-MM-DD".
//  Controlli e salvataggio stanno qui; funziona da solo, per la lista e per il dettaglio.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminPurchaseOrderFormViewModel: Identifiable {
    enum Mode {
        case create
        case edit(AdminPurchaseOrder)
    }

    let id = UUID()
    let mode: Mode
    let backend: AriaBackend
    let lookups: AdminPurchaseOrderLookups
    /// L'ordine salvato, per chi ha aperto il modulo.
    private let onSaved: (AdminPurchaseOrder) -> Void

    // MARK: - Campi

    var title = ""
    var vendorId: String?
    var hasOrderDate = false
    var orderDate = Calendar.current.startOfDay(for: .now)
    var hasExpectedDelivery = false
    var expectedDelivery = Calendar.current.startOfDay(for: .now)
    var shippingAddress = ""
    var notes = ""
    var plantId: String?

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(mode: Mode, backend: AriaBackend, lookups: AdminPurchaseOrderLookups,
         onSaved: @escaping (AdminPurchaseOrder) -> Void) {
        self.mode = mode
        self.backend = backend
        self.lookups = lookups
        self.onSaved = onSaved
        switch mode {
        case .create:
            plantId = backend.activePlantId ?? (backend.plants.count == 1 ? backend.plants.first?.id : nil)
        case .edit(let order):
            fill(from: order)
        }
    }

    private func fill(from order: AdminPurchaseOrder) {
        title = order.title
        vendorId = Self.normalized(order.vendorId)
        if let day = AdminPurchaseOrderDayText.localDate(fromRaw: order.orderDate) {
            hasOrderDate = true
            orderDate = day
        }
        if let day = AdminPurchaseOrderDayText.localDate(fromRaw: order.expectedDelivery) {
            hasExpectedDelivery = true
            expectedDelivery = day
        }
        shippingAddress = order.shippingAddress ?? ""
        notes = order.notes ?? ""
        plantId = order.plantId
    }

    // MARK: - Presentazione

    var isEditing: Bool { if case .edit = mode { true } else { false } }

    var navigationTitle: String {
        isEditing ? String(localized: "Edit purchase order") : String(localized: "New purchase order")
    }

    /// Il fornitore scelto non è nell'elenco (eliminato o non caricato): resta scelto.
    var hasUnlistedVendor: Bool {
        guard let vendorId else { return false }
        return !lookups.vendors.contains { $0.id == vendorId }
    }

    var plants: [AriaPlant] { backend.plants }

    /// Con più stabilimenti si sceglie; con uno solo si mostra il suo nome.
    var showsPlantPicker: Bool { plants.count > 1 }

    var plantName: String? { plants.first { $0.id == plantId }?.name }

    var hasUnlistedPlant: Bool {
        guard let plantId else { return false }
        return !plants.contains { $0.id == plantId }
    }

    /// Lo stabilimento è obbligatorio per un ordine nuovo, e per uno esistente che già ne ha uno.
    private var requiresPlant: Bool {
        switch mode {
        case .create: true
        case .edit(let order): order.plantId != nil
        }
    }

    // MARK: - Controlli

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var orderDay: String? { hasOrderDate ? AdminPurchaseOrderDayText.string(fromLocal: orderDate) : nil }

    private var expectedDay: String? {
        hasExpectedDelivery ? AdminPurchaseOrderDayText.string(fromLocal: expectedDelivery) : nil
    }

    /// La consegna prevista è prima della data dell'ordine.
    var dateError: String? {
        guard let orderDay, let expectedDay, expectedDay < orderDay else { return nil }
        return String(localized: "Expected delivery can't be before the order date.")
    }

    var canSave: Bool {
        !isSaving && !trimmedTitle.isEmpty && dateError == nil && (!requiresPlant || plantId != nil)
    }

    /// Qualcosa è cambiato: chiudere con un trascinamento perderebbe le modifiche.
    var hasChanges: Bool {
        switch mode {
        case .create:
            !trimmedTitle.isEmpty || vendorId != nil || hasOrderDate || hasExpectedDelivery
                || Self.normalized(shippingAddress) != nil || Self.normalized(notes) != nil
        case .edit(let order):
            !patch(from: order).isEmpty
        }
    }

    private static func normalized(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    // MARK: - Body

    private func createBody(plantId: String) -> AdminPurchaseOrderCreate {
        AdminPurchaseOrderCreate(
            title: trimmedTitle, plantId: plantId, vendorId: vendorId, orderDate: orderDay,
            expectedDelivery: expectedDay, shippingAddress: Self.normalized(shippingAddress),
            notes: Self.normalized(notes))
    }

    /// Solo i campi diversi dall'ordine di partenza; uno svuotato diventa null.
    private func patch(from order: AdminPurchaseOrder) -> AdminPurchaseOrderUpdate {
        var update = AdminPurchaseOrderUpdate()
        func text(_ field: AdminPurchaseOrderUpdate.Field, _ old: String?, _ new: String?) {
            if old != new { update.set(field, new) }
        }
        text(.title, Self.normalized(order.title), trimmedTitle)
        text(.vendorId, Self.normalized(order.vendorId), vendorId)
        text(.orderDate, AdminPurchaseOrderDayText.string(fromRaw: order.orderDate), orderDay)
        text(.expectedDelivery, AdminPurchaseOrderDayText.string(fromRaw: order.expectedDelivery), expectedDay)
        text(.shippingAddress, Self.normalized(order.shippingAddress), Self.normalized(shippingAddress))
        text(.notes, Self.normalized(order.notes), Self.normalized(notes))
        if let plantId, plantId != order.plantId { update.set(.plantId, plantId) }
        return update
    }

    // MARK: - Salvataggio

    /// `true` se salvato (o niente da salvare): il modulo si può chiudere.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        guard canSave else {
            errorMessage = dateError ?? String(localized: "Fill in the title and choose a plant.")
            return false
        }
        let api = AdminPurchaseOrdersAPI(api: backend.api)
        isSaving = true
        defer { isSaving = false }
        do {
            let saved: AdminPurchaseOrder
            switch mode {
            case .create:
                guard let plantId else { return false }
                saved = try await api.create(createBody(plantId: plantId))
            case .edit(let order):
                let update = patch(from: order)
                guard !update.isEmpty else { return true }
                saved = try await api.update(id: order.id, update)
            }
            onSaved(saved)
            return true
        } catch {
            if let failure = AdminPurchaseOrdersFailure.from(error, action: .write, backend: backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}
