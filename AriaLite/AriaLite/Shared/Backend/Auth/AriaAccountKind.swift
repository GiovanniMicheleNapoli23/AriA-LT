//
//  AriaAccountKind.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Che app vede chi ha fatto l'accesso. Lo decide il backend dalla membership, non il link usato:
//  GET /v1/me ha `operatorProfile` solo per un operatore mobile (anche un account della web la cui
//  membership è `mobile_operator` è un operatore). Tutti gli altri (owner, admin, member) vedono le
//  sezioni della web, ciascuno nei limiti del suo ruolo.
//

import Foundation

nonisolated enum AriaAccountKind: String, Codable, Sendable {
    /// Operatore mobile: chat, task assegnati e calendario.
    case `operator`
    /// Account della piattaforma: le sezioni della web app.
    case admin
}

/// I campi di GET /v1/me che servono a riconoscere l'account (MeResponse).
nonisolated struct AriaMe: Decodable, Sendable {
    let id: String
    let name: String?
    let email: String?
    let operatorProfile: AriaMobileProfile?

    /// L'account come lo ricorda l'app: per un operatore valgono nome ed email del profilo operatore.
    var account: AriaMobileAccount {
        if let profile = operatorProfile {
            return AriaMobileAccount(id: profile.id, name: profile.name, email: profile.email, kind: .operator)
        }
        return AriaMobileAccount(id: id, name: name ?? "", email: email ?? "", kind: .admin)
    }
}
