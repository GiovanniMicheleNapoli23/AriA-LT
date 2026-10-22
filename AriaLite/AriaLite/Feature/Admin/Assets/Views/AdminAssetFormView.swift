//
//  AdminAssetFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per creare o modificare un asset. Il form scorre da sé e "Save" sta sempre in alto:
//  va bene anche col telefono in orizzontale e la tastiera aperta.
//

import SwiftUI

struct AdminAssetFormView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, il form a metà non deve ripartire da capo.
    @State private var viewModel: AdminAssetFormViewModel
    let onSaved: (AdminAsset) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(viewModel: AdminAssetFormViewModel, onSaved: @escaping (AdminAsset) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                identity
                classification
                technical
                Section("Description") {
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focused)
                }
                Section("Notes") {
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focused)
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
            .navigationTitle(viewModel.isEditing ? "Edit asset" : "New asset")
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

    // MARK: Sezioni

    private var identity: some View {
        Section {
            TextField("Tag", text: $viewModel.tag, prompt: Text("e.g. M-101"))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .focused($focused)
            TextField("Name", text: $viewModel.name)
                .focused($focused)
        } footer: {
            if let message = viewModel.validationMessage { Text(message) }
        }
    }

    private var classification: some View {
        Section("Classification") {
            Picker("Type", selection: $viewModel.assetType) {
                ForEach(viewModel.typeOptions, id: \.self) { Text(viewModel.typeLabel($0)).tag($0) }
            }
            Picker("Status", selection: $viewModel.status) {
                ForEach(viewModel.statusOptions, id: \.self) { Text(viewModel.statusLabel($0)).tag($0) }
            }
            if !viewModel.plants.isEmpty {
                Picker("Plant", selection: $viewModel.plantId) {
                    if viewModel.plantId == nil { Text("Select").tag(String?.none) }
                    ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            TextField("Zone", text: $viewModel.zone)
                .focused($focused)
        }
        .tint(Color.liteAccent)
    }

    private var technical: some View {
        Section("Technical data") {
            TextField("Manufacturer", text: $viewModel.manufacturer)
                .focused($focused)
            TextField("Model", text: $viewModel.model)
                .focused($focused)
            TextField("Serial number", text: $viewModel.serialNumber)
                .autocorrectionDisabled()
                .focused($focused)
            LabeledContent("Power (kW)") {
                TextField("Power (kW)", text: $viewModel.power, prompt: Text(verbatim: "0"))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
            }
            TextField("Drive tag", text: $viewModel.driveTag)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused)
            TextField("Drive type", text: $viewModel.driveType)
                .focused($focused)
        }
    }
}
