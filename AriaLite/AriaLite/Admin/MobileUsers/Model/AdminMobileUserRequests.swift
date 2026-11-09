//
//  AdminMobileUserRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle chiamate che scrivono (camelCase, come il resto di …/mobile-users): promuovere un utente,
//  invitarne uno nuovo, cambiare stato o specialità. Nel PATCH i campi `nil` non si mandano.
//

import Foundation

nonisolated struct AdminMobileUserAdd: Encodable, Sendable {
    let userId: String
}

nonisolated struct AdminMobileUserInvite: Encodable, Sendable {
    let name: String
    let email: String
}

nonisolated struct AdminMobileUserUpdate: Encodable, Sendable {
    /// Solo `active` o `suspended`.
    var status: String?
    /// La lista intera (vuota = nessuna specialità): sostituisce quella sul server.
    var specialties: [String]?
}
