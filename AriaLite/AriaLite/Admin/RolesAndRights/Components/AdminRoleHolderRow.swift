//
//  AdminRoleHolderRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Una persona nella pagina Persone: il nome (apre la scheda se chi guarda può) e "Rimuovi dal ruolo" con lo scorrimento o il menu.
//

import SwiftUI

struct AdminRoleHolderRow: View {
    let holder: AdminRoleHolder
    let viewModel: AdminRoleDetailViewModel

    var body: some View {
        Group {
            if viewModel.canOpenPerson {
                NavigationLink(value: viewModel.personRoute(holder)) { label }
            } else {
                label
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if viewModel.mayChange {
                Button("Remove", systemImage: "person.badge.minus") { viewModel.remove(holder) }
                    .tint(.red)
                    .disabled(viewModel.isBusy(holder))
            }
        }
        .contextMenu {
            if viewModel.mayChange {
                Button("Remove from role", systemImage: "person.badge.minus", role: .destructive) {
                    viewModel.remove(holder)
                }
                .disabled(viewModel.isBusy(holder))
            }
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            Text(verbatim: viewModel.name(holder))
                .font(.body)
            Spacer(minLength: 8)
            if viewModel.isBusy(holder) {
                ProgressView()
            }
        }
    }
}
