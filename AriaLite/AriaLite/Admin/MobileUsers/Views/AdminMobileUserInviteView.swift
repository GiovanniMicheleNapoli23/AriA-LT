//
//  AdminMobileUserInviteView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio "Invite new operator": nome ed email; il server manda il link di accesso e occupa un posto.
//  "Send invite" sta sempre in alto: va bene anche in orizzontale con la tastiera.
//

import SwiftUI

struct AdminMobileUserInviteView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, il form a metà non deve ripartire da capo.
    @State private var viewModel: AdminMobileUserInviteViewModel
    let onInvited: (AdminMobileUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    private enum Field { case name, email }

    init(viewModel: AdminMobileUserInviteViewModel, onInvited: @escaping (AdminMobileUser) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onInvited = onInvited
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $viewModel.name, prompt: Text("e.g. Marco Rossi"))
                        .textContentType(.name)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .email }
                    TextField("Email", text: $viewModel.email, prompt: Text("name@company.com"))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .email)
                        .submitLabel(.done)
                } header: {
                    Text("Operator")
                } footer: {
                    if let message = viewModel.validationMessage {
                        Text(message)
                    } else {
                        Text("They'll get an email with a link to sign in to the app. The invite uses one mobile seat.")
                    }
                }
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Invite operator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.liteAccent)
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: send) {
                        if viewModel.isSaving { ProgressView() } else { Text("Send invite").fontWeight(.semibold) }
                    }
                    .tint(Color.liteAccent)
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func send() {
        focused = nil
        Task {
            if let user = await viewModel.save() {
                onInvited(user)
                dismiss()
            }
        }
    }
}
