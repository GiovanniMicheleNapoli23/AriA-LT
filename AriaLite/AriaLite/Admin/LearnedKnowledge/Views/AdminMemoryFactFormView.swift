//
//  AdminMemoryFactFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per scrivere un fatto nuovo o modificarne uno: testo, contesto, categoria e (solo per
//  quelli nuovi) stabilimento. "Save" sta sempre in alto: va bene anche in orizzontale con la tastiera.
//

import SwiftUI

struct AdminMemoryFactFormView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, il form a metà non deve ripartire da capo.
    @State private var viewModel: AdminMemoryFactFormViewModel
    let onSaved: (AdminMemoryFact) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(viewModel: AdminMemoryFactFormViewModel, onSaved: @escaping (AdminMemoryFact) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Fact", text: $viewModel.content,
                              prompt: Text("e.g. Pump P-12 must be primed before every restart"), axis: .vertical)
                        .lineLimit(3...10)
                        .focused($focused)
                } header: {
                    Text("Fact")
                } footer: {
                    if let message = viewModel.validationMessage {
                        Text(message)
                    } else if let footer = viewModel.contentFooter {
                        Text(footer)
                    }
                }
                Section {
                    TextField("Context", text: $viewModel.context, prompt: Text("When or where it applies"), axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused)
                    TextField("Category", text: $viewModel.category, prompt: Text("e.g. Safety, Maintenance"))
                        .focused($focused)
                    if !viewModel.isEditing, !viewModel.plants.isEmpty {
                        Picker("Plant", selection: $viewModel.plantId) {
                            if viewModel.plantId == nil { Text("Select").tag(String?.none) }
                            ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .tint(Color.liteAccent)
                    }
                } header: {
                    Text("Details")
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
            if let saved = await viewModel.save() {
                onSaved(saved)
                dismiss()
            }
        }
    }
}
