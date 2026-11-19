//
//  AriaComposerConnectorsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La logica del popover dei connettori sotto il campo della chat: i connettori collegati (per chi guarda,
//  come nel Marketplace), l'attesa, l'errore e "Manage connectors". La lista è quella del Marketplace
//  (AdminMarketplaceViewModel), riletta quando il popover si apre.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaComposerConnectorsViewModel {
    struct Row: Identifiable, Equatable {
        let provider: String
        let name: String

        var id: String { provider }
    }

    /// Cosa mostra il popover sopra il pulsante "Manage connectors".
    enum Content: Equatable {
        case loading
        /// Solo owner e admin leggono le connessioni dell'azienda.
        case restricted
        case failed(String)
        case empty
        case list([Row])
    }

    let marketplace: AdminMarketplaceViewModel

    init(marketplace: AdminMarketplaceViewModel) {
        self.marketplace = marketplace
    }

    var content: Content {
        guard marketplace.canManage else { return .restricted }
        let rows = connected
        if !rows.isEmpty { return .list(rows) }
        if let error = marketplace.errorMessage { return .failed(error) }
        return marketplace.hasLoaded ? .empty : .loading
    }

    /// Collegati per chi guarda (su un connettore personale, il suo account), in ordine di nome.
    private var connected: [Row] {
        marketplace.connectors
            .filter { $0.knownStatus == .connected }
            .map { Row(provider: $0.provider, name: marketplace.connectorName($0.provider)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// All'apertura: la lista si rilegge (una sessione ristretta non chiama le rotte dei connettori).
    func load() async {
        await marketplace.load()
    }
}
