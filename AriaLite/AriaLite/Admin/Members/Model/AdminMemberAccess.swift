//
//  AdminMemberAccess.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  I campi nuovi di GET /v1/members: `access` (lo stato della persona in azienda e nell'app) e `access_role`
//  (il suo ruolo di Roles & Rights, `{id, name, set}`).
//

import Foundation

/// `access` di una riga di GET /v1/members. `suspended` vale per l'intera azienda e copre gli stati `operator_*`.
/// Un valore sconosciuto vale `nil` (nessun badge, nessuna azione), come `null` (record legacy).
nonisolated enum AdminMemberAccess: String, Sendable, Hashable {
    case owner
    case admin
    case member
    case `operator`
    case operatorInvited = "operator_invited"
    case operatorSuspended = "operator_suspended"
    case suspended

    /// Ha, o ha avuto, l'accesso all'app dato da una licenza: operatore attivo, invitato o con l'app sospesa.
    var hasAppAccess: Bool {
        switch self {
        case .operator, .operatorInvited, .operatorSuspended: true
        case .owner, .admin, .member, .suspended: false
        }
    }
}

/// `access_role` di una persona: senza lo stato attivo/in pausa del ruolo.
nonisolated struct AdminMemberRoleBrief: Decodable, Sendable, Hashable {
    let id: String
    let name: String
    /// "high" o "low".
    let set: String?

    private enum CodingKeys: String, CodingKey { case id, name, set }

    init(id: String, name: String, set: String? = nil) {
        self.id = id
        self.name = name
        self.set = set
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            AdminMemberText.clean((try? c.decodeIfPresent(AriaJSON.self, forKey: key))?.stringValue)
        }
        guard let id = text(.id) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Role without id"))
        }
        self.id = id
        name = text(.name) ?? ""
        set = text(.set)
    }
}
