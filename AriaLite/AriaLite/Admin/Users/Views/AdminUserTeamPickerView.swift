//
//  AdminUserTeamPickerView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La pagina con la spunta per scegliere un team (Oggi e Pianifica): i team di GET /v1/lookups/teams, con la ricerca
//  se sono tanti. Scelto un team, la pagina si chiude e chi l'ha aperta riceve la scelta.
//

import SwiftUI

struct AdminUserTeamPickerView: View {
    let viewModel: AdminUserShiftsViewModel
    let title: LocalizedStringKey
    let selectedId: String?
    let onPick: (AdminMemberTeamOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        content
            .liteBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.loadTeams() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.teamsState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label(message, systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.loadTeams(force: true) } }
            }
        case .loaded:
            if viewModel.teams.isEmpty {
                ContentUnavailableView("No team", systemImage: "person.3")
            } else if viewModel.teamsAreSearchable {
                list.searchable(text: $query, prompt: Text("Search team…"))
            } else {
                list
            }
        }
    }

    private var list: some View {
        let teams = viewModel.teams(matching: query)
        return List {
            ForEach(teams) { team in
                Button {
                    onPick(team)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Text(verbatim: team.name)
                            .foregroundStyle(.primary)
                        if team.isAdHoc { AdminMemberBadge(text: String(localized: "Ad hoc"), tint: .orange) }
                        Spacer(minLength: 8)
                        if team.id == selectedId {
                            Image(systemName: "checkmark").foregroundStyle(Color.liteAccent)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if teams.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .ariaReadableWidth()
    }
}
