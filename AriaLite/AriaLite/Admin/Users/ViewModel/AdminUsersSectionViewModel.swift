//
//  AdminUsersSectionViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La sezione Users con le sue due viste, Users e Roles (Roles & Rights è confluita qui, come sulla web). Decide
//  quali viste si aprono (AdminUsersRules) e ricorda quella scelta tra un'entrata e l'altra. Se l'elenco delle
//  persone si chiude (403 del §2) e i ruoli restano aperti, la sezione mostra i ruoli invece di chiudersi.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminUsersSectionViewModel {
    @ObservationIgnored private let backend: AriaBackend
    @ObservationIgnored private let users: AdminUsersViewModel

    /// La vista scelta in alto; vale solo se si può aprire (`current`).
    var selected: AdminUsersTab = .users

    init(backend: AriaBackend, users: AdminUsersViewModel) {
        self.backend = backend
        self.users = users
    }

    var usersOpen: Bool {
        AdminUsersRules.usersViewOpen(backend.rights, operatorLayout: backend.usesOperatorLayout) && !users.isClosed
    }

    var rolesOpen: Bool { AdminUsersRules.rolesViewOpen(backend.rights) }

    var tabs: [AdminUsersTab] { AdminUsersRules.tabs(usersOpen: usersOpen, rolesOpen: rolesOpen) }

    /// La scelta in alto c'è solo se si aprono entrambe le viste.
    var showsTabs: Bool { tabs.count > 1 }

    var current: AdminUsersTab { AdminUsersRules.current(selected: selected, in: tabs) }

    /// Il passo "Invita" del giro guidato indica "Add user": serve la vista Users.
    func showUsers() { selected = .users }

    func reset() { selected = .users }
}
