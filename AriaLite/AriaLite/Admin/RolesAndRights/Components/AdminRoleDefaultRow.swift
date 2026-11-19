//
//  AdminRoleDefaultRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  La riga "Ruolo predefinito" (solo owner e admin): a destra il ruolo di ora, apre la pagina di scelta.
//

import SwiftUI

struct AdminRoleDefaultRow: View {
    let viewModel: AdminRolesViewModel

    var body: some View {
        NavigationLink(value: AdminRolesViewModel.Route.defaultRole) {
            LabeledContent {
                if viewModel.isSettingDefault {
                    ProgressView()
                } else {
                    Text(verbatim: viewModel.defaultValueText)
                }
            } label: {
                Text("Default role")
            }
        }
    }
}
