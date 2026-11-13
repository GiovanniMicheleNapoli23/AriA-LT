//
//  AdminRoleDeleteView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Lo sheet "Eliminare {ruolo}?": se qualcuno lo ha, prima si sceglie dove vanno (un ruolo o nessun ruolo).
//

import SwiftUI

struct AdminRoleDeleteView: View {
    @Bindable var viewModel: AdminRoleDeleteViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.asksWhereTo {
                    Section {
                        Picker("Move them to", selection: $viewModel.choice) {
                            ForEach(viewModel.targets) { target in
                                Text(verbatim: viewModel.label(target))
                                    .tag(Optional(AdminRoleDeleteViewModel.Choice.role(target.id)))
                            }
                            Text("No role").tag(Optional(AdminRoleDeleteViewModel.Choice.noRole))
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("Move them to")
                    } footer: {
                        Text(verbatim: viewModel.moveFirstText)
                    }
                } else {
                    Section {
                        Text("Nobody holds this role.")
                    }
                }
                Section {
                    Button("Delete role", role: .destructive) {
                        Task { if await viewModel.confirm() { dismiss() } }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!viewModel.canConfirm)
                } footer: {
                    if let message = viewModel.errorMessage {
                        Text(verbatim: message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .liteBackground()
            .navigationTitle("Delete \(viewModel.roleName)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if viewModel.isDeleting {
                    ToolbarItem(placement: .confirmationAction) { ProgressView() }
                }
            }
            .disabled(viewModel.isDeleting)
        }
        .presentationDetents([.medium, .large])
        .adminRolesToast(viewModel.owner)
    }
}
