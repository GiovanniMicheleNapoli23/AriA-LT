//
//  AdminMarketplaceIndex.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Il catalogo con gli indici che il Marketplace usa per cercare e per sapere chi contiene chi. Si costruisce
//  una volta sola, fuori dal main actor (AdminMarketplaceCatalog.loadIndex), alla prima apertura della sezione:
//  non pesa sull'avvio per chi il Marketplace non lo apre.
//

import Foundation

nonisolated struct AdminMarketplaceIndex: Sendable {
    /// Il catalogo intero, nella lingua dell'app.
    let catalog: [AdminMarketplaceItem]
    let itemsByID: [String: AdminMarketplaceItem]
    let connectorItems: [String: AdminMarketplaceItem]
    /// Id globale → i pacchetti che lo contengono (plugin, agent pack, full set).
    let bundledIn: [String: [String]]
    let searchIndex: [String: [String]]

    /// Prima del caricamento: niente elementi.
    static let empty = AdminMarketplaceIndex(catalog: [])

    init(catalog: [AdminMarketplaceItem]) {
        self.catalog = catalog
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        itemsByID = byID
        connectorItems = Dictionary(catalog.filter { $0.kind == .connector }.map { ($0.sourceId, $0) },
                                    uniquingKeysWith: { first, _ in first })
        bundledIn = Self.bundles(in: catalog, byID: byID)
        searchIndex = Dictionary(catalog.map { ($0.id, $0.searchHaystack) }, uniquingKeysWith: { first, _ in first })
    }

    /// Per ogni elemento, i pacchetti che lo portano: le skill di un plugin o di un agent pack, i componenti
    /// di un full set più le skill degli agent pack che contiene.
    private static func bundles(in catalog: [AdminMarketplaceItem], byID: [String: AdminMarketplaceItem]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        func add(_ contained: String, in bundle: AdminMarketplaceItem) {
            result[contained, default: []].append(bundle.id)
        }
        for bundle in catalog {
            for skill in bundle.plugin?.skills ?? [] { add("skill:\(skill)", in: bundle) }
            for skill in bundle.agentPack?.skills ?? [] { add("skill:\(skill)", in: bundle) }
            for component in bundle.fullSet?.components ?? [] {
                add(component, in: bundle)
                for skill in byID[component]?.agentPack?.skills ?? [] { add("skill:\(skill)", in: bundle) }
            }
        }
        return result
    }
}
