//
//  AdminMemberPayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle chiamate di scrittura: assegnazione di un turno, team ad hoc; e la risposta di POST /v1/users. Chiavi in camelCase:
//  l'endpoint `.snakeCased()` le scrive in snake_case. I campi `nil` non si mandano.
//

import Foundation

/// POST /v1/member-assignments.
nonisolated struct AdminMemberAssignmentCreate: Encodable, Sendable {
    var userId: String
    var teamId: String
    /// `YYYY-MM-DD`.
    var shiftDate: String
    var shiftType: String
    var notes: String?
}

/// POST /v1/teams/ad-hoc: solo `name` è obbligatorio.
nonisolated struct AdminMemberAdHocTeamCreate: Encodable, Sendable {
    var name: String
    var description: String?
    var plantId: String?
    var userIds: [String]
    /// `YYYY-MM-DD`.
    var shiftDates: [String]
    var shiftType: String
}

/// La risposta di POST /v1/users (UserBriefResponse): serve l'`id` per cercare la persona nell'elenco.
nonisolated struct AdminMemberCreated: Decodable, Sendable {
    let id: String
    let email: String
    let fullName: String?

    private enum CodingKeys: String, CodingKey { case id, email, fullName }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            AdminMemberText.clean((try? c.decodeIfPresent(AriaJSON.self, forKey: key))?.stringValue)
        }
        guard let id = text(.id) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Created user without id"))
        }
        self.id = id
        email = text(.email) ?? ""
        fullName = text(.fullName)
    }
}
