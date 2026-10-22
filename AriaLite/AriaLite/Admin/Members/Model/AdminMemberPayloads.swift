//
//  AdminMemberPayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle chiamate di scrittura: assegnazione di un turno, team ad hoc, nuovo utente. Chiavi in camelCase:
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

/// POST /v1/users: solo `email` è obbligatoria; nome, password e ruolo non si mandano se vuoti.
nonisolated struct AdminMemberUserCreate: Encodable, Sendable {
    var email: String
    var fullName: String?
    var password: String?
    var role: String?
}
