//
//  AdminTaskboardMember.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un membro dell'azienda (GET /v1/members, snake_case): fornisce i nomi e le scelte del filtro
//  "assegnato a" della bacheca. Obbligatorio solo l'id; il resto si legge senza errori.
//

import Foundation

nonisolated struct AdminTaskboardMember: Decodable, Sendable, Hashable, Identifiable {
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
