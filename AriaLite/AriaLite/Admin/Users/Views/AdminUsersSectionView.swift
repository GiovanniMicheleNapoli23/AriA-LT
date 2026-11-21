//
//  AdminUsersSectionView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La sezione Users della sidebar: la vista delle persone o quella dei ruoli, ognuna con la sua pila di
//  navigazione. La scelta tra le due sta nella barra (AdminUsersTabPicker) quando si aprono entrambe.
//

import SwiftUI

struct AdminUsersSectionView: View {
    let section: AdminUsersSectionViewModel
    let users: AdminUsersViewModel
    let roles: AdminRolesViewModel

    var body: some View {
        switch section.current {
        case .users:
            AdminUsersView(viewModel: users, tabs: section)
        case .roles:
            AdminRolesView(viewModel: roles, members: users, tabs: section)
        }
    }
}
