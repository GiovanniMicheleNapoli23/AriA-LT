//
//  AdminAssetHealthViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Il punteggio di salute di un asset nel dettaglio: si legge all'apertura (404: non ancora calcolato) e,
//  se il ruolo ha `refresh_health`, si ricalcola con il pulsante.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAssetHealthViewModel {
    let backend: AriaBackend
    let tag: String

    private(set) var health: AdminAssetHealth?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isRefreshing = false
    /// La lettura è andata male (non un 404): si mostra al posto del punteggio.
    private(set) var loadError: String?
    /// Il ricalcolo è andato male: il punteggio vecchio resta, l'errore sta sotto.
    private(set) var refreshError: String?

    init(backend: AriaBackend, tag: String) {
        self.backend = backend
        self.tag = tag
    }

    /// Il ruolo può chiedere il ricalcolo: senza, il pulsante non c'è.
    var canRefresh: Bool { backend.rights.can(.refreshHealth, in: .assets) }

    /// Letto bene ma il server non l'ha ancora calcolato (404).
    var isNotComputed: Bool { hasLoaded && health == nil && loadError == nil }

    func load() async {
        guard !isRefreshing else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            health = try await backend.api.call(AdminAssetsAPI.health(assetTag: tag))
            loadError = nil
        } catch {
            if Self.isNotFound(error) {
                health = nil
                loadError = nil
            } else if let message = AdminAssetsFailure.message(for: error, backend: backend) {
                loadError = message
            } else {
                return
            }
        }
        hasLoaded = true
    }

    func refresh() async {
        guard canRefresh, !isRefreshing else { return }
        isRefreshing = true
        refreshError = nil
        defer { isRefreshing = false }
        do {
            health = try await backend.api.call(AdminAssetsAPI.refreshHealth(assetTag: tag))
            loadError = nil
            hasLoaded = true
        } catch {
            refreshError = AdminAssetsFailure.message(for: error, backend: backend)
        }
    }

    nonisolated private static func isNotFound(_ error: any Error) -> Bool {
        if case .http(let status, _)? = error as? AriaError { return status == 404 }
        return false
    }
}
