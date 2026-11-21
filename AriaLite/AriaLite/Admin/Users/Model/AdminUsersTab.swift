//
//  AdminUsersTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Le due viste della sezione Users, come sulla web: le persone (Users) e i ruoli (Roles, l'ex sezione Roles &
//  Rights). Chi può aprirle entrambe le sceglie in alto; chi ne può aprire una sola vede solo quella.
//

import Foundation

nonisolated enum AdminUsersTab: String, CaseIterable, Identifiable, Sendable {
    case users, roles

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .users: "Users"
        case .roles: "Roles"
        }
    }
}
