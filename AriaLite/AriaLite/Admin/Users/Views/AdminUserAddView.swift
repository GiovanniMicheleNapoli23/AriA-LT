//
//  AdminUserAddView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il modulo "Add a person" in uno sheet (§6.1): nome, email, etichetta e livello (una pagina con il segno di
//  spunta), e "Add and send email". Un Form di sistema; i controlli e le due chiamate sono nel view model.
//

import SwiftUI

struct AdminUserAddView: View {
    @Bindable var viewModel: AdminUserAddViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                personSection
                Section {
                    Picker("Label", selection: $viewModel.label) {
                        ForEach(AdminUserAddViewModel.PersonLabel.allCases) { label in
                            Text(verbatim: label.title).tag(label)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    NavigationLink {
                        AdminUserLevelPickerPage(groups: viewModel.levelGroups, selection: $viewModel.level)
                    } label: {
                        LabeledContent("Level") { Text(verbatim: viewModel.levelTitle) }
                    }
                } footer: {
                    if let hint = viewModel.ownerHint { Text(verbatim: hint) }
                }
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Add a person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Add and send email") { Task { if await viewModel.submit() { dismiss() } } }
                            .disabled(!viewModel.canSubmit)
                    }
                }
            }
            .disabled(viewModel.isSubmitting)
            .interactiveDismissDisabled(viewModel.hasChanges || viewModel.isSubmitting)
            .task { await viewModel.loadRolesIfNeeded() }
        }
        .adminUsersToast(viewModel.owner)
    }

    private var personSection: some View {
        Section {
            TextField("Full name", text: $viewModel.name)
                .textContentType(.name)
                .submitLabel(.next)
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } footer: {
            if let error = viewModel.emailError {
                Text(verbatim: error).foregroundStyle(.red)
            }
        }
    }
}
