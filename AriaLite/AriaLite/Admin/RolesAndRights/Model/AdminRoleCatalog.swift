//
//  AdminRoleCatalog.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il catalogo delle sezioni (GET …/access/catalog): una voce per sezione, nell'ordine della sidebar della web,
//  con le sue azioni. Cambia di rado: la web lo tiene 5 minuti.
//

import Foundation

/// I gruppi della sidebar della web, nell'ordine in cui si mostrano.
nonisolated enum AdminRoleGroup: String, Sendable, CaseIterable, Identifiable {
    case operational
    case resources
    case purchases
    case analytics
    case intelligence
    case configuration

    var id: String { rawValue }
}

nonisolated struct AdminRoleCatalogSection: Decodable, Identifiable, Hashable, Sendable {
    let section: String
    /// `nil`: un gruppo che l'app non conosce (finisce in fondo).
    let group: AdminRoleGroup?
    let labelKey: String?
    /// Vero: la sezione non si offre a un ruolo base.
    let highOnly: Bool
    /// Gli slug delle azioni, in ordine di catalogo. Vuoto: la sezione è un solo interruttore.
    let actions: [String]

    var id: String { section }

    private enum CodingKeys: String, CodingKey { case section, group, labelKey, highOnly, actions }
    private struct Action: Decodable { let action: String }

    init(section: String, group: AdminRoleGroup?, labelKey: String? = nil, highOnly: Bool = false, actions: [String] = []) {
        self.section = section
        self.group = group
        self.labelKey = labelKey
        self.highOnly = highOnly
        self.actions = actions
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        section = try c.decode(String.self, forKey: .section)
        group = (try? c.decodeIfPresent(String.self, forKey: .group)).flatMap(AdminRoleGroup.init(rawValue:))
        labelKey = try c.decodeIfPresent(String.self, forKey: .labelKey)
        highOnly = try c.decodeIfPresent(Bool.self, forKey: .highOnly) ?? false
        actions = (try? c.decodeIfPresent(AriaLossyArray<Action>.self, forKey: .actions))?.items.map(\.action) ?? []
    }
}

/// GET …/access/catalog
nonisolated struct AdminRoleCatalog: Decodable, Sendable {
    let sections: [AdminRoleCatalogSection]

    private enum CodingKeys: String, CodingKey { case sections }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sections = try c.decodeIfPresent(AriaLossyArray<AdminRoleCatalogSection>.self, forKey: .sections)?.items ?? []
    }
}
