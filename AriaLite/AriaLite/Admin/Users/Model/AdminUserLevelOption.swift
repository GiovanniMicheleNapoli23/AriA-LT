//
//  AdminUserLevelOption.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il livello di una persona come scelta: titolare, un ruolo, o nessun ruolo ("Member" in un'azienda senza ruoli),
//  e una voce del selettore con il suo gruppo, se è disattivata e perché (§5.2, §6.1).
//

import Foundation

nonisolated enum AdminUserLevelValue: Hashable, Sendable {
    case owner
    case role(String)
    /// Nessun ruolo; "Member" in un'azienda senza ruoli.
    case none

    var roleId: String? {
        if case .role(let id) = self { return id }
        return nil
    }
}

nonisolated struct AdminUserLevelOption: Hashable, Sendable, Identifiable {
    enum Group: Hashable, Sendable {
        case owner
        case high
        case low
        case none
    }

    enum Hint: Hashable, Sendable {
        /// "3 owners already"
        case ownerCap
        /// "The last owner can't step down"
        case lastOwner

        var text: String {
            switch self {
            case .ownerCap: String(localized: "3 owners already")
            case .lastOwner: String(localized: "The last owner can't step down")
            }
        }
    }

    let value: AdminUserLevelValue
    let group: Group
    /// Il nome del ruolo, già con "(paused)" se è in pausa; "Owner", "No role" o "Member" per gli altri.
    let title: String
    var isDisabled = false
    var hint: Hint?

    var id: AdminUserLevelValue { value }
}
