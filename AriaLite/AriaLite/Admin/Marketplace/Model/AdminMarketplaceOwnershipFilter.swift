//
//  AdminMarketplaceOwnershipFilter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il filtro "cosa è mio" del Marketplace: tutto, solo quello che l'azienda ha (connettori collegati e
//  acquisti) o solo quello che manca. L'incluso nel piano ma non usato non conta come posseduto, come sulla web.
//

import Foundation

nonisolated enum AdminMarketplaceOwnershipFilter: String, Sendable, CaseIterable, Identifiable {
    case all
    case owned
    case available

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: String(localized: "All")
        case .owned: String(localized: "Owned")
        case .available: String(localized: "Available")
        }
    }
}
