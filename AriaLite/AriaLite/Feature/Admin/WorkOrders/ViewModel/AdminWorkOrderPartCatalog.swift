//
//  AdminWorkOrderPartCatalog.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le scelte dei form dei costi e dei modelli: ricambi del magazzino (GET /v1/spare-parts dello stabilimento
//  attivo), persone (GET /v1/users) e asset (GET /v1/assets). Ogni elenco si scarica la prima volta che
//  serve; se il ruolo non può leggerlo, il form resta col testo libero.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderPartCatalog {
    let backend: AriaBackend

    private(set) var parts: [AdminWorkOrderPartOption] = []
    private(set) var users: [AdminWorkOrderUser] = []
    private(set) var assets: [AdminWorkOrderAsset] = []
    /// Elenchi che il ruolo non può leggere (o che non sono arrivati).
    private(set) var partsUnavailable = false
    private(set) var usersUnavailable = false
    private(set) var assetsUnavailable = false

    @ObservationIgnored private var partsPlantId: String?
    @ObservationIgnored private var hasParts = false
    @ObservationIgnored private var hasUsers = false
    @ObservationIgnored private var hasAssets = false

    init(backend: AriaBackend) {
        self.backend = backend
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    func reset() {
        parts = []
        users = []
        assets = []
        partsUnavailable = false
        usersUnavailable = false
        assetsUnavailable = false
        hasParts = false
        hasUsers = false
        hasAssets = false
        partsPlantId = nil
    }

    /// I ricambi dello stabilimento attivo; si riscaricano se lo stabilimento cambia.
    func loadParts() async {
        let plantId = backend.activePlantId
        guard !hasParts || partsPlantId != plantId else { return }
        do {
            parts = try await api.partOptions(plantId: plantId).sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            partsUnavailable = false
            hasParts = true
            partsPlantId = plantId
        } catch {
            partsUnavailable = !AdminWorkOrderFailure.isCancellation(error)
        }
    }

    func loadUsers() async {
        guard !hasUsers else { return }
        do {
            users = try await api.users().filter(\.isActive).sorted {
                $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            usersUnavailable = false
            hasUsers = true
        } catch {
            usersUnavailable = !AdminWorkOrderFailure.isCancellation(error)
        }
    }

    /// Gli asset dello stabilimento attivo (quelli senza stabilimento valgono ovunque).
    func loadAssets() async {
        guard !hasAssets else { return }
        do {
            assets = try await api.assets().sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
            assetsUnavailable = false
            hasAssets = true
        } catch {
            assetsUnavailable = !AdminWorkOrderFailure.isCancellation(error)
        }
    }

    // MARK: Ricerca

    func part(_ id: String?) -> AdminWorkOrderPartOption? {
        guard let id else { return nil }
        return parts.first { $0.id == id }
    }

    func user(_ id: String?) -> AdminWorkOrderUser? {
        guard let id else { return nil }
        return users.first { $0.id == id }
    }

    func asset(_ tag: String?) -> AdminWorkOrderAsset? {
        guard let tag else { return nil }
        return assets.first { $0.tag == tag }
    }

    // MARK: Voci per AdminWorkOrderChoiceList

    var partChoices: [AdminWorkOrderChoice] {
        parts.map { part in
            AdminWorkOrderChoice(id: part.id, title: part.name,
                                 subtitle: AdminWorkOrderFormat.joined([part.code, AdminWorkOrderCostFormat.stock(of: part),
                                                                        part.unitPrice.map(AdminWorkOrderCostFormat.money)]))
        }
    }

    var userChoices: [AdminWorkOrderChoice] {
        users.map { AdminWorkOrderChoice(id: $0.id, title: $0.displayName, subtitle: $0.fullName == nil ? nil : $0.email) }
    }

    var assetChoices: [AdminWorkOrderChoice] {
        let plantId = backend.activePlantId
        return assets.filter { plantId == nil || $0.plantId == nil || $0.plantId == plantId }.map {
            AdminWorkOrderChoice(id: $0.tag, title: $0.tag, subtitle: AdminWorkOrderFormat.joined([$0.name, $0.zone]))
        }
    }
}
