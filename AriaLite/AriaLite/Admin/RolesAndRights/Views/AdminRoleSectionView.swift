//
//  AdminRoleSectionView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  La pagina di una sezione di un ruolo: l'interruttore "Accesso" e, a sezione accesa, un interruttore per ogni azione. Rilegge la riga dal view model a ogni disegno.
//

import SwiftUI

struct AdminRoleSectionView: View {
    let viewModel: AdminRoleDetailViewModel
    let section: String

    var body: some View {
        let row = viewModel.sectionRow(section)
        Group {
            if let row {
                list(row)
            } else {
                // L'elenco torna indietro da solo quando il ruolo o la sezione non ci sono più.
                ProgressView()
            }
        }
        .liteBackground()
        .navigationTitle(row?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func list(_ row: AdminRoleSectionRow) -> some View {
        List {
            Section {
                Toggle(isOn: Binding(get: { row.isOn }, set: { viewModel.setSection(row.section, on: $0) })) {
                    AdminRoleToggleLabel(title: Text("Access"), notInYourRole: row.notInYourRole)
                }
                .disabled(!row.isEnabled)
            } footer: {
                Text(verbatim: viewModel.accessFooter(for: row))
            }
            if viewModel.showsActions(row) {
                Section("Actions") {
                    ForEach(row.chips) { chip in
                        Toggle(isOn: Binding(get: { chip.isOn },
                                             set: { _ in viewModel.toggleAction(chip.action, in: row.section) })) {
                            AdminRoleToggleLabel(title: Text(verbatim: chip.title), notInYourRole: chip.notInYourRole)
                        }
                        .disabled(!chip.isEnabled)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .ariaReadableWidth()
    }
}
