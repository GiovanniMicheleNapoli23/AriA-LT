//
//  AdminRolePerson.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Le persone di Roles & Rights: chi ha un ruolo (GET …/access/roles/{id}/members) e chi può riceverlo
//  (GET …/access/assignable-members, col ruolo che ha ora).
//

import Foundation

nonisolated struct AdminRoleHolder: Decodable, Identifiable, Hashable, Sendable {
    let userId: String
    let name: String?
    let fieldLabel: String?

    var id: String { userId }
}

nonisolated struct AdminRoleCandidate: Decodable, Identifiable, Hashable, Sendable {
    nonisolated struct CurrentRole: Decodable, Hashable, Sendable {
        let id: String
        let name: String
        let set: String?
    }

    let userId: String
    let name: String?
    let fieldLabel: String?
    /// `nil`: la persona non ha un ruolo.
    let role: CurrentRole?

    var id: String { userId }

    private enum CodingKeys: String, CodingKey { case userId, name, fieldLabel, role }

    init(userId: String, name: String?, fieldLabel: String? = nil, role: CurrentRole? = nil) {
        self.userId = userId
        self.name = name
        self.fieldLabel = fieldLabel
        self.role = role
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        fieldLabel = try c.decodeIfPresent(String.self, forKey: .fieldLabel)
        role = try? c.decodeIfPresent(CurrentRole.self, forKey: .role)
    }
}

/// `{ "members": [...] }` di entrambe le rotte.
nonisolated struct AdminRoleMembersList<Member: Decodable & Sendable>: Decodable, Sendable {
    let members: [Member]

    private enum CodingKeys: String, CodingKey { case members }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        members = try c.decodeIfPresent(AriaLossyArray<Member>.self, forKey: .members)?.items ?? []
    }
}
