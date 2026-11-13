//
//  AdminMembersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Members, come la pagina /members della web: le licenze dell'app (solo owner e admin), filtri
//  (ruolo, stato, team) e ricerca in alto, una riga per persona con la sua scheda a tocco e un "+" per crearne
//  una nuova (solo owner e admin).
//

import SwiftUI

struct AdminMembersView: View {
    @Bindable var viewModel: AdminMembersViewModel

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    seatsLine
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
            .navigationDestination(for: AdminMemberRoute.self) { route in
                AdminMemberDetailView(userId: route.userId, owner: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                if viewModel.canCreate {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New person", systemImage: "plus") { viewModel.startCreatingMember() }
                    }
                }
            }
            .searchable(text: $viewModel.query, prompt: Text("Name or email"))
            .sheet(item: $viewModel.newMemberForm) { form in
                AdminMemberCreateView(viewModel: form)
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
                    NavigationLink(value: AdminMemberRoute(userId: member.id)) {
                        AdminMemberRow(member: member, roleLine: viewModel.roleLine(for: member),
                                       badge: viewModel.badge(for: member))
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

    /// "App seats: 7 of 10", solo per owner e admin quando le licenze sono arrivate.
    @ViewBuilder
    private var seatsLine: some View {
        if let text = viewModel.seatsText {
            AdminMemberSeatsLine(text: text, isFull: viewModel.seatsAreFull)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
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
