//
//  AdminDowntimeFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Registra un fermo macchina (POST /v1/asset-downtime) o lo modifica (PATCH /v1/asset-downtime/{id}):
//  inizio, fine (vuota = ancora in corso), motivo e l'ordine di lavoro collegato.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminDowntimeFormViewModel {
    let backend: AriaBackend
    let assetTag: String
    let plantId: String?
    /// Gli ordini dell'asset, per collegarne uno senza scrivere l'id.
    let workOrders: [AdminAssetWorkOrder]
    let original: AdminDowntime?

    var startedAt: Date
    var isOngoing: Bool
    var endedAt: Date
    var reason: String
    var workOrderId: String?

    private(set) var isSaving = false
    var errorMessage: String?

    init(backend: AriaBackend, assetTag: String, plantId: String?, workOrders: [AdminAssetWorkOrder],
         editing downtime: AdminDowntime?) {
        self.backend = backend
        self.assetTag = assetTag
        self.plantId = plantId
        self.workOrders = workOrders
        original = downtime
        let start = downtime?.startedAt ?? .now
        startedAt = start
        isOngoing = downtime.map(\.isOpen) ?? true
        endedAt = downtime?.endedAt ?? max(start, .now)
        reason = downtime?.reason ?? ""
        workOrderId = downtime?.workOrderId
    }

    var isEditing: Bool { original != nil }
    var title: String { isEditing ? String(localized: "Edit downtime") : String(localized: "Log downtime") }

    /// L'ordine collegato, anche se non è fra quelli scaricati (resta scelto com'era).
    var workOrderOptions: [AdminWorkOrderOption] {
        var options = workOrders.map { AdminWorkOrderOption(id: $0.id, title: $0.title) }
        if let workOrderId, !options.contains(where: { $0.id == workOrderId }) {
            options.append(AdminWorkOrderOption(id: workOrderId, title: workOrderId))
        }
        return options
    }

    // MARK: Validazione

    private var trimmedReason: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var validationMessage: String? {
        if startedAt > .now.addingTimeInterval(60) { return String(localized: "The start can't be in the future.") }
        if !isOngoing, endedAt < startedAt { return String(localized: "The end must come after the start.") }
        if !isEditing, plantId == nil { return String(localized: "Select a plant before logging downtime.") }
        return nil
    }

    private var changes: AdminPatchBody {
        var body = AdminPatchBody()
        guard let original else { return body }
        if original.startedAt.map({ abs($0.timeIntervalSince(startedAt)) >= 1 }) ?? true {
            body.value("started_at", .string(AdminDowntime.wire(startedAt)), was: .null)
        }
        if isOngoing {
            if original.hasEnd { body.value("ended_at", .null, was: .string("")) }
        } else if original.endedAt.map({ abs($0.timeIntervalSince(endedAt)) >= 1 }) ?? true {
            body.value("ended_at", .string(AdminDowntime.wire(endedAt)), was: .null)
        }
        body.text("reason", reason, was: original.reason)
        body.value("work_order_id", workOrderId.map(AriaJSON.string) ?? .null,
                   was: original.workOrderId.map(AriaJSON.string) ?? .null)
        return body
    }

    var canSave: Bool {
        guard validationMessage == nil, !isSaving else { return false }
        return !isEditing || !changes.isEmpty
    }

    // MARK: Salvataggio

    func save() async -> AdminDowntime? {
        guard canSave else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let original {
                guard let id = original.serverId else { return nil }
                return try await backend.api.call(AdminAssetsAPI.updateDowntime(id: id, changes))
            }
            guard let plantId else { return nil }
            let body = AdminDowntimeCreate(assetTag: assetTag, startedAt: AdminDowntime.wire(startedAt),
                                           endedAt: isOngoing ? nil : AdminDowntime.wire(endedAt),
                                           reason: trimmedReason.isEmpty ? nil : trimmedReason,
                                           workOrderId: workOrderId, plantId: plantId)
            return try await backend.api.call(AdminAssetsAPI.createDowntime(body))
        } catch {
            errorMessage = AdminAssetsFailure.message(for: error, backend: backend)
            return nil
        }
    }
}

/// Una scelta del picker "Linked work order".
nonisolated struct AdminWorkOrderOption: Sendable, Hashable, Identifiable {
    let id: String
    let title: String
}

/// Il form si apre con `.sheet(item:)`: l'identità è quella dell'oggetto.
extension AdminDowntimeFormViewModel: Identifiable {}
