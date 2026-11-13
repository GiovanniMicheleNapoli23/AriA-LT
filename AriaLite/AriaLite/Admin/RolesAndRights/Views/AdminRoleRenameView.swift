//
//  AdminRoleRenameView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Il foglio "Rinomina ruolo": un campo col nome; resta aperto con l'errore se il nome c'è già, si chiude a salvataggio riuscito.
//

import SwiftUI

struct AdminRoleRenameView: View {
    @Bindable var viewModel: AdminRoleDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $viewModel.nameDraft)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .onSubmit { Task { await viewModel.saveName() } }
                } footer: {
                    if let error = viewModel.nameError {
                        Text(verbatim: error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Rename role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSavingName {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await viewModel.saveName() } }
                            .disabled(!viewModel.canSaveName)
                    }
                }
            }
            .disabled(viewModel.isSavingName)
            .onAppear { isNameFocused = true }
        }
        .presentationDetents([.medium])
        .adminRolesToast(viewModel.owner)
    }
}
