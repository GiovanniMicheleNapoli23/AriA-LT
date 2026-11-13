//
//  AdminRolesView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  La sezione Roles & Rights: elenco dei ruoli in una lista raggruppata (ruolo predefinito per gli admin, Owner, il tuo, alti, base), e sheet per creare, eliminare e aggiungere persone.
//

import SwiftUI

struct AdminRolesView: View {
    @Bindable var viewModel: AdminRolesViewModel
    /// Per la scheda della persona, che si apre dalla pagina Persone di un ruolo.
    let members: AdminMembersViewModel

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            content
                .liteBackground()
                .navigationTitle("Roles & Rights")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                    if viewModel.placeholder == nil || viewModel.placeholder == .empty {
                        ToolbarItem(placement: .topBarTrailing) { AdminRoleNewButton(viewModel: viewModel) }
                    }
                }
                .navigationDestination(for: AdminRolesViewModel.Route.self) { route in
                    switch route {
                    case .role(let id): AdminRoleDetailView(viewModel: viewModel.detail(for: id))
                    case .people(let id): AdminRolePeopleView(viewModel: viewModel.detail(for: id))
                    case .section(let id, let section):
                        AdminRoleSectionView(viewModel: viewModel.detail(for: id), section: section)
                    case .person(let id): AdminMemberDetailView(userId: id, owner: members)
                    case .defaultRole: AdminRoleDefaultView(viewModel: viewModel)
                    }
                }
        }
        .sheet(item: $viewModel.createForm) { form in
            AdminRoleCreateView(viewModel: form)
        }
        .sheet(item: $viewModel.deleteForm) { form in
            AdminRoleDeleteView(viewModel: form)
        }
        .sheet(item: $viewModel.addPeople) { form in
            AdminRoleAddPeopleView(viewModel: form)
        }
        .adminRolesToast(viewModel)
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let placeholder = viewModel.placeholder {
            ScrollView {
                AdminRolesPlaceholder(placeholder: placeholder, viewModel: viewModel)
                    .containerRelativeFrame([.horizontal, .vertical])
            }
            .refreshable { await viewModel.load() }
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if viewModel.showsDefaultRole {
                Section {
                    AdminRoleDefaultRow(viewModel: viewModel)
                } footer: {
                    Text(verbatim: viewModel.defaultFooter)
                }
            }
            if let own = viewModel.ownRole {
                Section("Your role") {
                    AdminRoleRow(role: own, viewModel: viewModel)
                }
            }
            if !viewModel.highRoles.isEmpty {
                Section {
                    ForEach(viewModel.highRoles) { role in
                        AdminRoleRow(role: role, viewModel: viewModel)
                    }
                } header: {
                    Text("High roles")
                } footer: {
                    Text("High roles can create and manage their own low roles.")
                }
            }
            if !viewModel.lowRoles.isEmpty {
                Section("Low roles") {
                    ForEach(viewModel.lowRoles) { role in
                        AdminRoleRow(role: role, viewModel: viewModel)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load() }
        .ariaReadableWidth()
    }
}
