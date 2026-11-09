//
//  AdminExtractionReviewAPI+Client.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le chiamate della revisione sui quattro tipi con un'interfaccia sola: elenco dei pending, rilettura,
//  modifica (PATCH), approvazione in blocco e AI. Smista sulle API giuste: AdminAssetsAPI e
//  AdminSparePartsAPI per asset e ricambi, AdminExtractionReviewAPI per allarmi e piani.
//

import Foundation

nonisolated struct AdminExtractionReviewClient: Sendable {
    let api: AriaAPIClient

    private var spareParts: AdminSparePartsAPI { AdminSparePartsAPI(api: api) }

    // MARK: Lettura

    /// Gli elementi di un tipo in uno stato (`draft`, `staged`…).
    func items(_ kind: AdminExtractionKind, status: String, plantId: String?) async throws -> [AdminExtractionItem] {
        switch kind {
        case .assets:
            try await api.call(AdminAssetsAPI.assets(status: status)).items.map(AdminExtractionItem.asset)
        case .alarms:
            try await api.call(AdminExtractionReviewAPI.alarms(status: status)).items.map(AdminExtractionItem.alarm)
        case .maintenancePlans:
            try await api.call(AdminExtractionReviewAPI.maintenancePlans(status: status)).items.map(AdminExtractionItem.plan)
        case .spareParts:
            try await spareParts.list(status: status, plantId: plantId).map(AdminExtractionItem.part)
        }
    }

    /// La versione aggiornata di un elemento (all'apertura del dettaglio).
    func refreshed(_ item: AdminExtractionItem) async throws -> AdminExtractionItem {
        switch item {
        case .asset(let asset): .asset(try await api.call(AdminAssetsAPI.asset(tag: asset.tag)))
        case .alarm(let alarm): .alarm(try await api.call(AdminExtractionReviewAPI.alarm(id: try Self.id(alarm.serverId))))
        case .plan(let plan): .plan(try await api.call(AdminExtractionReviewAPI.maintenancePlan(id: try Self.id(plan.serverId))))
        case .part(let part): .part(try await spareParts.part(id: part.id))
        }
    }

    // MARK: Scrittura

    /// PATCH dei campi cambiati (chiavi snake_case); risponde con l'elemento salvato.
    func update(_ item: AdminExtractionItem, _ changes: AdminPatchBody) async throws -> AdminExtractionItem {
        let id = try Self.id(item.serverId)
        switch item {
        case .asset: return .asset(try await api.call(AdminAssetsAPI.update(assetId: id, changes)))
        case .alarm: return .alarm(try await api.call(AdminExtractionReviewAPI.updateAlarm(id: id, changes)))
        case .plan: return .plan(try await api.call(AdminExtractionReviewAPI.updateMaintenancePlan(id: id, changes)))
        case .part:
            // SparePartUpdate ha le sue chiavi (camelCase): una chiave che non conosce non si manda.
            var body = AdminSparePartUpdate()
            for (key, value) in changes.fields {
                if let field = AdminSparePartUpdate.Field(rawValue: Self.camelCase(key)) { body.fields[field] = value }
            }
            return .part(try await spareParts.update(id: id, body))
        }
    }

    /// Solo lo stato (approva, rifiuta).
    func setStatus(_ item: AdminExtractionItem, _ status: String) async throws -> AdminExtractionItem {
        var body = AdminPatchBody()
        body.value("status", .string(status), was: .null)
        return try await update(item, body)
    }

    /// POST bulk-approve (solo asset e allarmi ce l'hanno). La risposta non ha schema: non si legge.
    func bulkApprove(_ kind: AdminExtractionKind, ids: [String]) async throws {
        switch kind {
        case .assets: _ = try await api.call(AdminExtractionReviewAPI.approveAssets(ids: ids))
        case .alarms: _ = try await api.call(AdminExtractionReviewAPI.approveAlarms(ids: ids))
        case .maintenancePlans, .spareParts: throw AriaError.http(status: 405, detail: "bulk-approve")
        }
    }

    // MARK: AI

    func askAI(_ item: AdminExtractionItem, _ request: AdminExtractionAIRequest) async throws -> AriaJSON {
        let id = try Self.id(item.serverId)
        return switch item {
        case .asset: try await api.call(AdminExtractionReviewAPI.analyzeAsset(id: id, request))
        case .alarm: try await api.call(AdminExtractionReviewAPI.improveAlarm(id: id, request))
        case .plan: try await api.call(AdminExtractionReviewAPI.improveMaintenancePlan(id: id, request))
        case .part: try await api.call(AdminExtractionReviewAPI.analyzeSparePart(id: id, request))
        }
    }

    // MARK: Supporto

    private static func id(_ serverId: String?) throws -> String {
        guard let serverId else { throw AriaError.http(status: 404, detail: "missing id") }
        return serverId
    }

    private static func camelCase(_ key: String) -> String {
        let parts = key.split(separator: "_")
        guard let first = parts.first else { return key }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
}
