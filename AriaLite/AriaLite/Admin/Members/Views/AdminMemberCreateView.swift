//
//  AdminMemberCreateView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "New person" in uno sheet: nome, email, ruolo (obbligatorio), qualifica facoltativa e
//  "Può usare l'app". Un Form di sistema; controlli e salvataggio sono nel view model, che a creazione riuscita
//  chiude il foglio e apre la scheda della persona.
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
                personSection
                roleSection
                labelSection
                appSection
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("New person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Create") { Task { await viewModel.save() } }
                            .disabled(!viewModel.canSave)
                    }
                }
            }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
            .task { await viewModel.loadRoles() }
        }
    }

    // MARK: - Sezioni

    private var personSection: some View {
        Section {
            TextField("Full name", text: $viewModel.name)
                .textContentType(.name)
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if viewModel.duplicate != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Already in the list.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    Button("Open their profile") { viewModel.openDuplicate() }
                        .font(.footnote.weight(.semibold))
                }
            }
        } footer: {
            Text("Name and email are required.")
        }
    }

    private var roleSection: some View {
        Section {
            Picker("Role", selection: $viewModel.roleId) {
                Text("Choose a role").tag(String?.none)
                ForEach(viewModel.roles) { role in
                    Text(verbatim: role.name).tag(Optional(role.id))
                }
            }
            .disabled(viewModel.roles.isEmpty)
        } header: {
            Text("Role")
        } footer: {
            if let failure = viewModel.rolesFailure {
                Text(verbatim: failure)
            } else if viewModel.hasNoActiveRoles {
                Text("There are no active roles. Create or turn on a role in Roles & Rights first.")
            } else {
                Text("Required. The role decides what they can do.")
            }
        }
    }

    private var labelSection: some View {
        Section {
            Picker("Label", selection: $viewModel.label) {
                ForEach(AdminMemberLabel.allCases) { label in
                    Text(verbatim: label.title).tag(label)
                }
            }
        } header: {
            Text("Label")
        } footer: {
            Text("Optional. A label doesn't give any access.")
        }
    }

    private var appSection: some View {
        Section {
            Toggle("Can use the app", isOn: Binding(get: { viewModel.wantsAppEffective },
                                                    set: { viewModel.wantsApp = $0 }))
                .disabled(!viewModel.appToggleEnabled)
            if let seats = viewModel.seatsText {
                Text(verbatim: seats)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text(verbatim: viewModel.appFootnote)
        }
    }
}
