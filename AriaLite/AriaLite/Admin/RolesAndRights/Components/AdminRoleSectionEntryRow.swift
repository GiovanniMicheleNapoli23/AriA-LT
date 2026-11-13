//
//  AdminRoleSectionEntryRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Una sezione nel dettaglio del ruolo: un interruttore se non ha azioni, altrimenti un link alla sua pagina col riassunto di cosa è acceso.
//

import SwiftUI

struct AdminRoleSectionEntryRow: View {
    let row: AdminRoleSectionRow
    let viewModel: AdminRoleDetailViewModel

    var body: some View {
        if row.hasActions {
            NavigationLink(value: AdminRolesViewModel.Route.section(role: viewModel.roleId, section: row.section)) {
                LabeledContent {
                    Text(verbatim: row.summary)
                } label: {
                    AdminRoleToggleLabel(title: Text(verbatim: row.title), notInYourRole: row.notInYourRole)
                }
            }
        } else {
            Toggle(isOn: Binding(get: { row.isOn }, set: { viewModel.setSection(row.section, on: $0) })) {
                AdminRoleToggleLabel(title: Text(verbatim: row.title), notInYourRole: row.notInYourRole)
            }
            .disabled(!row.isEnabled)
        }
    }
}
