//
//  AdminMarketplaceRoute.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Dove porta un tocco nel Marketplace: un connettore che il server conosce va al suo dettaglio vero
//  (AdminConnectorDetailView), ogni altro elemento del catalogo alla sua pagina (AdminMarketplaceItemDetailView).
//

import Foundation

nonisolated enum AdminMarketplaceRoute: Hashable, Sendable {
    /// Per `provider`, una riga di GET /connectors.
    case connector(String)
    /// Per id globale del catalogo (`"skill:shift-handover"`).
    case item(String)
}
