//
//  AdminRoleRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Una riga dell'elenco: nome, persone e origine, stato a destra. Si apre il dettaglio; "In pausa" e "Elimina" stanno nello
//  scorrimento e nel menu a tocco prolungato (l'interruttore è nel dettaglio).
//

import SwiftUI

struct AdminRoleRow: View {
    let role: AdminRole
    let viewModel: AdminRolesViewModel

    var body: some View {
        NavigationLink(value: AdminRolesViewModel.Route.role(role.id)) {
            HStack(spacing: 8) {
                details
                Spacer(minLength: 8)
                trailing
            }
        }
        .swipeActions(edge: .leading) {
            if viewModel.canTogglePause(role) { pauseButton }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if viewModel.canAskDelete(role) { deleteButton }
        }
        .contextMenu {
            if viewModel.canTogglePause(role) { pauseButton }
            if viewModel.canAskDelete(role) {
                Button("Delete", systemImage: "trash", role: .destructive) { viewModel.askDelete(role) }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(verbatim: role.name)
                    .font(.body)
                    .foregroundStyle(role.enabled ? Color.primary : Color.secondary)
                if viewModel.isOwn(role) {
                    Image(systemName: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            Text(verbatim: viewModel.subtitle(role))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if role.exceedsOwner {
                Label {
                    Text("Holds sections its owner role lacks")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if viewModel.isBusy(role) {
            ProgressView()
        } else if let status = viewModel.status(role) {
            Text(verbatim: status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var pauseButton: some View {
        Button { viewModel.togglePause(role) } label: {
            Label(viewModel.pauseTitle(role), systemImage: viewModel.pauseSymbol(role))
        }
        .tint(role.enabled ? Color.gray : Color.liteAccent)
    }

    /// Non è `.destructive`: quel ruolo fa uscire la riga con un'animazione, e qui si apre solo la conferma.
    private var deleteButton: some View {
        Button("Delete", systemImage: "trash") { viewModel.askDelete(role) }
            .tint(.red)
    }
}
