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
    /// Solo con `Company-Id`: il ruolo nell'azienda e se la sessione dell'app è ristretta (operatore).
    let membership: AriaMeMembership?
    /// Solo con `Company-Id`: ruolo e diritti nell'azienda (AriaAccess). `nil` su un backend precedente.
    let access: AriaAccess?

    private enum CodingKeys: String, CodingKey { case id, name, email, operatorProfile, membership, access }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        operatorProfile = try c.decodeIfPresent(AriaMobileProfile.self, forKey: .operatorProfile)
        // Un backend senza il campo, o con una forma nuova, non rompe l'accesso.
        membership = try? c.decodeIfPresent(AriaMeMembership.self, forKey: .membership)
        access = try? c.decodeIfPresent(AriaAccess.self, forKey: .access)
    }

    /// L'account come lo ricorda l'app: per un operatore valgono nome ed email del profilo operatore.
    var account: AriaMobileAccount {
        if let profile = operatorProfile {
            return AriaMobileAccount(id: profile.id, name: profile.name, email: profile.email, kind: .operator)
        }
        return AriaMobileAccount(id: id, name: name ?? "", email: email ?? "", kind: .admin)
    }
}

/// `membership` di GET /v1/me per l'azienda di `Company-Id`. Dall'app `restricted` è vero per un operatore (ogni
/// membro, anche quando la sessione segue il ruolo) e falso per un owner o un admin: decide il layout dell'operatore.
nonisolated struct AriaMeMembership: Decodable, Sendable, Equatable {
    let role: String?
    let restricted: Bool
}
