//
//  AdminDocumentPage.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una pagina delle liste del servizio documenti (`{items, total, skip, limit}`). Lettura tollerante:
//  una riga che non si legge si scarta; se arriva un array semplice vale come pagina unica.
//

import Foundation

nonisolated struct AdminDocumentPage<Element: Decodable & Sendable>: Decodable, Sendable {
    let items: [Element]
    /// Quanti sono in tutto sul server; `nil` se non lo dice.
    let total: Int?

    private enum CodingKeys: String, CodingKey { case items, total }

    init(from decoder: any Decoder) throws {
        if let rows = try? decoder.singleValueContainer().decode(AriaLossyArray<Element>.self) {
            items = rows.items
            total = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decode(AriaLossyArray<Element>.self, forKey: .items))?.items ?? []
        total = try? c.decodeIfPresent(Int.self, forKey: .total)
    }
}
