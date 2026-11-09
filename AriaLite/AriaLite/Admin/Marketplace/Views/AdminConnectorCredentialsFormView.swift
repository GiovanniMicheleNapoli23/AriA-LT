//
//  AdminConnectorCredentialsFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio della chiave di un connettore (MaintainX o server MCP con credenziale statica).
//  "Save" verifica la chiave sul server; se la chiave vede più organizzazioni, il foglio resta aperto per sceglierne una.
//

import SwiftUI

struct AdminConnectorCredentialsFormView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, il form a metà non deve ripartire da capo.
    @State private var viewModel: AdminConnectorCredentialsFormViewModel
    var onFinished: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(viewModel: AdminConnectorCredentialsFormViewModel, onFinished: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.mode == .remote { server }
                credential
                if viewModel.choosesOrganization { organization }
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(Color.liteAccent)
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if viewModel.isSaving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .tint(Color.liteAccent)
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func save() {
        focused = false
        Task {
            if await viewModel.save() {
                onFinished()
                dismiss()
            }
        }
    }

    // MARK: Sezioni

    private var server: some View {
        Section("Server") {
            TextField("Server URL", text: $viewModel.serverURL, prompt: Text("https://…"))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
            TextField("Display name", text: $viewModel.displayName)
                .focused($focused)
            Picker("Authentication", selection: $viewModel.authMode) {
                ForEach(AdminConnectorAuthMode.allCases) { Text($0.label).tag($0) }
            }
            .tint(Color.liteAccent)
            if viewModel.needsHeaderName {
                TextField("Header name", text: $viewModel.headerName, prompt: Text("e.g. X-API-Key"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
            }
        }
    }

    @ViewBuilder
    private var credential: some View {
        if viewModel.needsKey {
            Section {
                SecureField(viewModel.keyFieldTitle, text: $viewModel.apiKey)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
            } header: {
                Text("Credential")
            } footer: {
                Text("Aria checks the key before saving it. A wrong key leaves the current connection as it is.")
            }
        }
    }

    private var organization: some View {
        Section("Organization") {
            Picker("Organization", selection: $viewModel.organizationId) {
                Text("Select").tag(String?.none)
                ForEach(viewModel.organizations) { Text($0.name).tag(Optional($0.id)) }
            }
            .tint(Color.liteAccent)
        }
    }
}
