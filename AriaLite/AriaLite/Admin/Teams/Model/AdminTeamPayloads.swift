//
//  AdminTeamPayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle scritture: crea e modifica squadra, aggiungi membro, modifica di un ordine dalla bacheca. Chiavi
//  in camelCase: l'endpoint `.snakeCased()` le scrive in snake_case.
//

import Foundation

/// POST /v1/teams. Solo `name` è obbligatorio.
nonisolated struct AdminTeamCreate: Encodable, Sendable {
    var name: String
    var description: String?
    var plantId: String?
}

/// PATCH /v1/teams/{id}: solo i campi cambiati; `.null` svuota il campo sul server.
nonisolated struct AdminTeamUpdate: Encodable, Sendable {
    enum Field: String, CodingKey, Sendable, Hashable {
        case name, description, plantId
    }

    var fields: [Field: AriaJSON] = [:]

    var isEmpty: Bool { fields.isEmpty }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Field.self)
        for (field, value) in fields { try container.encode(value, forKey: field) }
    }
}

/// POST /v1/teams/{id}/members.
nonisolated struct AdminTeamMemberCreate: Encodable, Sendable {
    var userId: String
    var roleInTeam: String?
}

/// PATCH /v1/work-orders/{id} dalla bacheca: un solo campo alla volta, lo stato o la squadra.
nonisolated struct AdminTeamWorkOrderPatch: Encodable, Sendable {
    var status: String?
    var assignedToTeamId: String?
}
