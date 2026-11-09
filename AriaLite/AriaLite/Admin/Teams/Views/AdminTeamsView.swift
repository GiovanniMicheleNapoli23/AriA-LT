//
//  AdminTeamsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Teams, come la pagina /teams della web: filtro per stabilimento, ricerca, una scheda per squadra con
//  il suo carico, dettaglio a tocco, "Board" in alto e "+" per crearne una nuova.
//

import SwiftUI

struct AdminTeamsView: View {
    @Bindable var viewModel: AdminTeamsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.showsPlantFilter {
                        AdminTeamPlantFilter(viewModel: viewModel)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                    errorPill
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Teams")
            .navigationDestination(for: AdminTeam.self) { team in
                AdminTeamDetailView(team: team, owner: viewModel)
            }
            .navigationDestination(for: AdminTeamBoardRoute.self) { route in
                AdminTeamBoardView(owner: viewModel, teamId: route.teamId)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: AdminTeamBoardRoute(teamId: nil)) {
                        Label("Board", systemImage: "rectangle.split.3x1")
                    }
                    .disabled(viewModel.teams.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New team", systemImage: "plus") { viewModel.startCreating() }
                        .disabled(!viewModel.hasLoaded)
                }
            }
            .searchable(text: $viewModel.query, prompt: Text("Name, description or plant"))
            .sheet(item: $viewModel.newTeamForm) { form in
                AdminTeamFormView(viewModel: form)
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let placeholder = viewModel.placeholder {
            AdminTeamsPlaceholder(placeholder: placeholder,
                                  retry: { Task { await viewModel.refresh() } },
                                  clearFilters: { withAnimation(.snappy) { viewModel.clearFilters() } })
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 10, alignment: .top)], spacing: 10) {
                ForEach(viewModel.visibleTeams) { team in
                    NavigationLink(value: team) {
                        AdminTeamRow(team: team, plantName: viewModel.plantName(for: team.plantId),
                                     workload: viewModel.workloads[team.id])
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
