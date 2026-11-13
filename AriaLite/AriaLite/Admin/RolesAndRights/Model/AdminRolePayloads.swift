//
//  AdminRolePayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  I body delle scritture di Roles & Rights, in camelCase. Il server rifiuta i campi sconosciuti (422).
//  Attenzione ai `null`: `{"moveTo": null}` e `{"roleId": null}` vogliono dire qualcosa (nessun ruolo) e
//  non vanno omessi come farebbe la codifica sintetizzata.
//

import Foundation

nonisolated struct AdminRoleCreate: Encodable, Sendable {
    let name: String
    let set: AdminRoleSet
    /// Sempre vuoto: le sezioni si accendono nel dettaglio.
    let grants: [String: [String]]
}

nonisolated struct AdminRoleRename: Encodable, Sendable {
    let version: Int
    let name: String
}

nonisolated struct AdminRoleEnabled: Encodable, Sendable {
    let enabled: Bool
    let version: Int
}

/// Una sezione accesa (con le azioni) o spenta (`enabled` falso, azioni vuote).
nonisolated struct AdminRoleGrant: Encodable, Sendable {
    let enabled: Bool
    let actions: [String]
    let version: Int
}

nonisolated struct AdminRoleDefault: Encodable, Sendable {
    let roleId: String
}

/// PUT /members/{userId}/access-role: `roleId` nil = togliere il ruolo, mandato come `null`.
nonisolated struct AdminRoleAssignment: Encodable, Sendable {
    let roleId: String?

    private enum CodingKeys: String, CodingKey { case roleId }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(roleId, forKey: .roleId)
    }
}

/// Il body di DELETE …/access/roles/{id} quando qualcuno ha il ruolo: `moveTo` nil = restano senza ruolo,
/// mandato come `null` (senza body, o con `{}`, il server rifiuta con 409 `role_has_members`).
nonisolated struct AdminRoleDeleteMove: Encodable, Sendable {
    let moveTo: String?

    private enum CodingKeys: String, CodingKey { case moveTo }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(moveTo, forKey: .moveTo)
    }
}
