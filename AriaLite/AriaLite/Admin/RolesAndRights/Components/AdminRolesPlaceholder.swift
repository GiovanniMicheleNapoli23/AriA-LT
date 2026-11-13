//
//  AdminRolesPlaceholder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Cosa mostrare al posto dell'elenco: caricamento, nessun accesso, errore con riprova, nessun ruolo.
//

import SwiftUI

struct AdminRolesPlaceholder: View {
    let placeholder: AdminRolesViewModel.Placeholder
    let viewModel: AdminRolesViewModel

    var body: some View {
        switch placeholder {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 240)
        case .noAccess:
            ContentUnavailableView("You don't have access to Roles & Rights.", systemImage: "lock")
                .frame(minHeight: 240)
        case .failed:
            ContentUnavailableView {
                Label("Roles couldn't be loaded.", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.load(forceCatalog: true) } }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liteAccent)
                    .foregroundStyle(Color.liteOnAccent)
            }
            .frame(minHeight: 240)
        case .empty:
            ContentUnavailableView {
                Label("No roles yet", systemImage: "person.badge.key")
            } description: {
                Text("Create a role to give people sections of ARIA.")
            } actions: {
                AdminRoleNewButton(viewModel: viewModel)
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liteAccent)
                    .foregroundStyle(Color.liteOnAccent)
            }
            .frame(minHeight: 240)
        }
    }
}
