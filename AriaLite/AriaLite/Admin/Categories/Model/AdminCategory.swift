//
//  AdminCategory.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una categoria come la manda il backend (CategoryResponse). Lettura tollerante: senza `id` la riga si salta
//  (non si può modificare né eliminare), i campi illeggibili valgono come assenti.
//

import Foundation

nonisolated struct AdminCategory: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String
    /// Testo libero (lo schema non ha un elenco): si mostra com'è.
    var entityType: String
    var description: String?
    /// Colore esadecimale, es. "#3B82F6". Se non si legge, la categoria non ha colore.
    var color: String?
    /// Nome di un simbolo SF Symbols, se il server lo manda.
    var icon: String?
    var plantId: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, entityType, description, color, icon, plantId
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        func text(_ key: CodingKeys) -> String? { json(key)?.nonEmptyString }
        guard let id = text(.id) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Category without id")
            )
        }
        self.id = id
        name = text(.name) ?? ""
        entityType = text(.entityType) ?? ""
        description = text(.description)
        color = text(.color)
        icon = text(.icon)
        plantId = text(.plantId)
    }

    /// Il tipo come lo mostra la lista: se manca, un trattino.
    var entityTypeLabel: String { entityType.isEmpty ? "-" : entityType }
}
