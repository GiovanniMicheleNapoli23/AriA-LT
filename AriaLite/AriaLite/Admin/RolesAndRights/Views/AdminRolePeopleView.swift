//
//  AdminRolePeopleView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  La pagina Persone di un ruolo: chi lo ha (scheda a tocco, "Rimuovi" con lo scorrimento) e "Aggiungi persone".
//

import SwiftUI

struct AdminRolePeopleView: View {
    let viewModel: AdminRoleDetailViewModel

    var body: some View {
        content
            .liteBackground()
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.mayChange {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add people", systemImage: "person.badge.plus") { viewModel.addPeople() }
                    }
                }
            }
            .task { await viewModel.loadPeople() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.people {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label("People couldn't be loaded.", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.loadPeople() } }
            }
        case .empty:
            ContentUnavailableView {
                Label("Nobody holds this role yet.", systemImage: "person.2")
            } actions: {
                if viewModel.mayChange {
                    Button("Add people") { viewModel.addPeople() }
                }
            }
        case .loaded(let holders):
            List(holders) { holder in
                AdminRoleHolderRow(holder: holder, viewModel: viewModel)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.loadPeople() }
            .ariaReadableWidth()
        }
    }
}
