//
//  AdminAssetDetailViewModel+Delete.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  L'eliminazione dell'asset dal dettaglio (DELETE /v1/assets/{asset_id}), solo per il ruolo che può:
//  vale quello che servirebbe a rifiutarlo, secondo lo stato salvato dell'asset.
//

import Foundation

extension AdminAssetDetailViewModel {
    /// Il cestino c'è solo se l'asset ha un id del server e il ruolo può eliminarlo (mai disattivato: si nasconde).
    var canDeleteAsset: Bool {
        asset.serverId != nil && reviewing == nil && backend.rights.canDelete(stored: asset.status ?? "draft", in: .assets)
    }

    /// `true` se eliminato: la schermata si chiude e la lista lo toglie. Un 404 vuol dire che non c'era già più.
    func deleteAsset() async -> Bool {
        guard canDeleteAsset, !isDeletingAsset, let id = asset.serverId else { return false }
        isDeletingAsset = true
        defer { isDeletingAsset = false }
        do {
            _ = try await backend.api.call(AdminAssetsAPI.delete(assetId: id))
        } catch {
            if case .http(let status, _)? = error as? AriaError, status == 404 {
                // Già eliminato altrove: per la lista è come se l'avessimo eliminato noi.
            } else {
                assetDeleteError = AdminAssetsFailure.message(for: error, backend: backend)
                return false
            }
        }
        onAssetDeleted(asset)
        return true
    }
}
