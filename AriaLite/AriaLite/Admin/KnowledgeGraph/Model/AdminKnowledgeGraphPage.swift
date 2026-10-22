//
//  AdminKnowledgeGraphPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una pagina delle rotte paginate (documenti, elaborazioni): `items` più il totale sul server.
//  Accetta anche un array semplice, se un giorno il server smettesse di avvolgerlo.
//

import Foundation

nonisolated struct AdminKnowledgeGraphPage<Element: Decodable & Sendable>: Decodable, Sendable {
    let items: [Element]
    let total: Int?

    private enum CodingKeys: String, CodingKey { case items, total }

    init(from decoder: any Decoder) throws {
        if let rows = try? decoder.singleValueContainer().decode(AriaLossyArray<Element>.self) {
            items = rows.items
            total = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent(AriaLossyArray<Element>.self, forKey: .items))?.items ?? []
        total = try? c.decodeIfPresent(Int.self, forKey: .total)
    }
}
