//
//  AdminRoleDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il dettaglio di un ruolo in una lista raggruppata: stato, persone, livello, poi le sezioni per gruppo (interruttore o link alla pagina).
//

import SwiftUI

struct AdminRoleDetailView: View {
    @Bindable var viewModel: AdminRoleDetailViewModel

    var body: some View {
        Group {
            if viewModel.role != nil {
                list
            } else {
                // L'elenco torna indietro da solo quando il ruolo non c'è più.
                ProgressView()
            }
        }
        .liteBackground()
        .navigationTitle(viewModel.role?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.mayChange || viewModel.mayDelete {
                ToolbarItem(placement: .topBarTrailing) { moreMenu }
            }
        }
        .sheet(isPresented: $viewModel.isRenaming, onDismiss: { viewModel.cancelRenaming() }) {
            AdminRoleRenameView(viewModel: viewModel)
        }
    }

    private var list: some View {
        List {
            Section {
                if viewModel.mayChange {
                    Toggle(viewModel.toggleTitle, isOn: Binding(get: { viewModel.isActive },
                                                                set: { viewModel.setActive($0) }))
                        .disabled(viewModel.isBusy)
                } else {
                    LabeledContent("Status", value: viewModel.statusText)
                }
                NavigationLink(value: AdminRolesViewModel.Route.people(viewModel.roleId)) {
                    LabeledContent("People", value: viewModel.peopleCountText)
                }
                LabeledContent("Level", value: viewModel.levelText)
                if let createdBy = viewModel.createdByText {
                    LabeledContent("Created by", value: createdBy)
                }
            } footer: {
                if let footer = viewModel.footerText {
                    Text(verbatim: footer)
                }
            }
            ForEach(viewModel.sectionGroups) { group in
                Section {
                    ForEach(group.rows) { row in
                        AdminRoleSectionEntryRow(row: row, viewModel: viewModel)
                    }
                } header: {
                    Text(verbatim: group.title)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .ariaReadableWidth()
    }

    private var moreMenu: some View {
        Menu {
            if viewModel.mayChange {
                Button("Rename", systemImage: "pencil") { viewModel.startRenaming() }
            }
            if viewModel.mayDelete {
                Button("Delete role", systemImage: "trash", role: .destructive) { viewModel.askDelete() }
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }
}
