//
//  AdminMembersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Members, come la pagina /members della web: filtri (ruolo, stato, team) e ricerca in alto,
//  una scheda per membro, dettaglio a tocco e un menu "+" per aggiungere un membro o creare un team ad hoc.
//

import SwiftUI

struct AdminMembersView: View {
    @Bindable var viewModel: AdminMembersViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.hasLoaded && !viewModel.members.isEmpty {
                        AdminMemberFilterBar(viewModel: viewModel)
                            .padding(.top, 8)
                    }
                    errorPill
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Members")
            .navigationDestination(for: AdminMember.self) { member in
                AdminMemberDetailView(member: member, owner: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Add", systemImage: "plus") {
                        Button("Add member", systemImage: "person.badge.plus") { viewModel.startCreatingMember() }
                        Button("New ad-hoc team", systemImage: "person.3") { viewModel.startCreatingAdHocTeam() }
                            .disabled(!viewModel.hasLoaded)
                    }
                }
            }
            .searchable(text: $viewModel.query, prompt: Text("Name or email"))
            .sheet(item: $viewModel.newMemberForm) { form in
                AdminMemberCreateView(viewModel: form)
            }
            .sheet(item: $viewModel.adHocTeamForm) { form in
                AdminMemberAdHocTeamView(viewModel: form)
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let placeholder = viewModel.placeholder {
            AdminMembersPlaceholder(placeholder: placeholder,
                                    retry: { Task { await viewModel.refresh() } },
                                    clearFilters: { withAnimation(.snappy) { viewModel.clearFilters() } })
        } else {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.visibleMembers) { member in
                    NavigationLink(value: member) {
                        AdminMemberRow(member: member)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)

            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
        }
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.refreshFailed {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
                Text("Couldn't refresh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await viewModel.refresh() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
}
