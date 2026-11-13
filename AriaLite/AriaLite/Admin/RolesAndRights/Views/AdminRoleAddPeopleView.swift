//
//  AdminRoleAddPeopleView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Lo sheet "Aggiungi persone a {ruolo}": chi si può spostare, cercato per nome; un tocco dà il ruolo e lo sheet resta aperto.
//

import SwiftUI

struct AdminRoleAddPeopleView: View {
    @Bindable var viewModel: AdminRoleAddPeopleViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .liteBackground()
                .navigationTitle("Add people to \(viewModel.roleName)")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: Text("Search by name…"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }
        .presentationDetents([.medium, .large])
        .adminRolesToast(viewModel.owner)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView("People couldn't be loaded.", systemImage: "exclamationmark.triangle")
        case .empty:
            ContentUnavailableView("Nobody to add.", systemImage: "person.2")
        case .loaded(let candidates):
            List(candidates) { candidate in
                Button { Task { await viewModel.add(candidate) } } label: {
                    AdminPersonPickRow(
                        name: viewModel.name(candidate),
                        detail: viewModel.currentRole(candidate),
                        isSelected: false,
                        isBusy: viewModel.isBusy(candidate)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isBusy(candidate))
            }
            .scrollContentBackground(.hidden)
        }
    }
}
