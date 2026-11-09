//
//  AdminMemberCreateView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "Add member" in uno sheet: email, nome, ruolo e password (campo protetto, facoltativa).
//  Un Form di sistema; controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminMemberCreateView: View {
    @Bindable var viewModel: AdminMemberCreateViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Full name", text: $viewModel.fullName)
                        .textContentType(.name)
                } footer: {
                    Text("Email is required.")
                }
                Section {
                    HStack {
                        TextField("Role", text: $viewModel.role)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        roleMenu
                    }
                } header: {
                    Text("Role")
                }
                Section {
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.newPassword)
                } header: {
                    Text("Password")
                } footer: {
                    Text("Optional.")
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Add member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Add") { Task { if await viewModel.save() { dismiss() } } }
                            .disabled(!viewModel.canSave)
                    }
                }
            }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
        }
    }

    private var roleMenu: some View {
        Menu {
            ForEach(viewModel.roleSuggestions, id: \.self) { role in
                Button {
                    viewModel.role = role
                } label: {
                    if viewModel.isCurrentRole(role) {
                        Label(viewModel.roleLabel(role), systemImage: "checkmark")
                    } else {
                        Text(verbatim: viewModel.roleLabel(role))
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.up.chevron.down")
        }
        .accessibilityLabel(Text("Suggested roles"))
    }
}
