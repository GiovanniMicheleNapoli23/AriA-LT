//
//  AdminWorkflowFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per creare un flusso (nome, descrizione, modello di partenza) o cambiarne nome e descrizione.
//  "Save" sta sempre in alto: va bene anche in orizzontale con la tastiera.
//

import SwiftUI

struct AdminWorkflowFormView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, il form a metà non deve ripartire da capo.
    @State private var viewModel: AdminWorkflowFormViewModel
    let onSaved: (AdminWorkflow) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(viewModel: AdminWorkflowFormViewModel, onSaved: @escaping (AdminWorkflow) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $viewModel.name, prompt: Text("e.g. Maintenance assistant"))
                        .focused($focused)
                    TextField("Description", text: $viewModel.description,
                              prompt: Text("What this flow is for"), axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focused)
                } header: {
                    Text("Details")
                } footer: {
                    if let message = viewModel.validationMessage { Text(message) }
                }
                if !viewModel.isEditing { templateSection }
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
            .task { await viewModel.loadTemplates() }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    /// Un flusso nuovo può partire dal grafo di un modello; se non ce ne sono, la sezione non c'è.
    @ViewBuilder
    private var templateSection: some View {
        if viewModel.isLoadingTemplates {
            Section { ProgressView() } header: { Text("Template") }
        } else if !viewModel.templates.isEmpty {
            Section {
                Picker("Start from", selection: $viewModel.template) {
                    Text("Empty flow").tag(AdminWorkflowTemplate?.none)
                    ForEach(viewModel.templates) { Text($0.name).tag(Optional($0)) }
                }
                .tint(Color.liteAccent)
            } header: {
                Text("Template")
            } footer: {
                if let description = viewModel.template?.description { Text(description) }
            }
        }
    }

    private func save() {
        focused = false
        Task {
            if let flow = await viewModel.save() {
                onSaved(flow)
                dismiss()
            }
        }
    }
}
