//
//  AdminWorkOrderLookups.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le anagrafiche che servono agli ordini: persone (GET /v1/users), squadre (GET /v1/teams) e asset
//  (GET /v1/assets). Servono per scegliere nel form e per mostrare un nome al posto di un id.
//

import Foundation

nonisolated struct AdminWorkOrderUser: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var email: String
    var fullName: String?
    var role: String?
    var isActive: Bool

    private enum CodingKeys: String, CodingKey { case id, email, fullName, role, isActive }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        email = f.text(.email) ?? ""
        fullName = f.text(.fullName)
        role = f.text(.role)
        isActive = f.value(Bool.self, .isActive) ?? true
    }

    var displayName: String { fullName ?? (email.isEmpty ? id : email) }
}

nonisolated struct AdminWorkOrderTeam: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var name: String
    var plantId: String?
    var memberCount: Int

    private enum CodingKeys: String, CodingKey { case id, name, plantId, members }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        name = f.text(.name) ?? id
        plantId = f.id(.plantId)
        memberCount = f.value([AriaJSON].self, .members)?.count ?? 0
    }
}

nonisolated struct AdminWorkOrderAsset: Decodable, Sendable, Hashable, Identifiable {
    let tag: String
    var name: String
    var zone: String?
    var plantId: String?

    var id: String { tag }

    private enum CodingKeys: String, CodingKey { case tag, name, zone, plantId }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        // Gli ordini puntano all'asset col tag: senza tag non si può scegliere.
        guard let tag = f.text(.tag) else {
            throw DecodingError.keyNotFound(CodingKeys.tag, .init(codingPath: decoder.codingPath, debugDescription: "tag"))
        }
        self.tag = tag
        name = f.text(.name) ?? tag
        zone = f.text(.zone)
        plantId = f.id(.plantId)
    }
}
