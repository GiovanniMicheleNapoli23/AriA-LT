//
//  AdminUsersPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Cosa si vede al posto delle persone (§3.5): la prima lettura in corso, la lettura fallita (con Riprova),
//  nessuna persona, nessuna persona che passa la ricerca e i filtri.
//

import SwiftUI

struct AdminUsersPlaceholder: View {
    let placeholder: AdminUsersViewModel.Placeholder
    let viewModel: AdminUsersViewModel

    var body: some View {
        switch placeholder {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 240)
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load the people of this workspace.", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.refresh() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liteAccent)
                    .foregroundStyle(Color.liteOnAccent)
            }
            .frame(minHeight: 240)
        case .empty:
            ContentUnavailableView {
                Label("No one here yet", systemImage: "person.2")
            } description: {
                Text("Add the people who work in this workspace.")
            } actions: {
                if viewModel.canAdd {
                    Button("Add user") { viewModel.startAdding() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.liteAccent)
                        .foregroundStyle(Color.liteOnAccent)
                }
            }
            .frame(minHeight: 240)
        case .noMatches:
            ContentUnavailableView {
                Label("No one matches these filters.", systemImage: "line.3.horizontal.decrease.circle")
            } actions: {
                if viewModel.hasActiveFilters {
                    Button("Clear filters") { withAnimation(.snappy) { viewModel.clearFilters() } }
                }
            }
            .frame(minHeight: 240)
        }
    }
}
