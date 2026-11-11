//
//  AdminMaintenanceFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per creare o modificare un piano. Un Form di sistema come gli altri moduli (asset, allarme):
//  piano, dove si trova, programmazione, date, passi, ricambi, descrizione. Tiene il campo attivo sopra la
//  tastiera anche in orizzontale e "Save" sta sempre in alto.
//

import SwiftUI

struct AdminMaintenanceFormView: View {
    /// In `@State`: il foglio si ricostruisce col genitore, il form a metà non deve ripartire da capo.
    @State private var viewModel: AdminMaintenanceFormViewModel
    let onSaved: (AdminMaintenancePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(viewModel: AdminMaintenanceFormViewModel, onSaved: @escaping (AdminMaintenancePlan) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                plan
                location
                AdminMaintenanceFormScheduleSections(viewModel: viewModel, focus: $focused)
                if let message = viewModel.validationMessage {
                    Section {
                        Label(message, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
            .task { await viewModel.loadAssets() }
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

    private var plan: some View {
        Section("Plan") {
            TextField("Name", text: $viewModel.name)
                .focused($focused)
            TextField("Category", text: $viewModel.category)
                .focused($focused)
            if viewModel.showsStatus {
                Picker("Status", selection: $viewModel.status) {
                    ForEach(viewModel.statusOptions, id: \.self) { Text(viewModel.statusLabel($0)).tag($0) }
                }
            }
        }
        .tint(Color.liteAccent)
    }

    /// Stabilimento prima dell'asset: le scelte dell'asset sono quelle dello stabilimento.
    /// Senza l'elenco degli asset (niente diritto o niente risposta) il tag si scrive a mano.
    private var location: some View {
        Section {
            if !viewModel.plants.isEmpty {
                Picker("Plant", selection: $viewModel.plantId) {
                    if viewModel.plantId == nil { Text("Select").tag(String?.none) }
                    ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                }
            }
            if viewModel.assetChoices.isEmpty {
                TextField("Asset tag", text: $viewModel.assetTag)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .focused($focused)
            } else {
                Picker("Asset", selection: $viewModel.selectedAssetTag) {
                    Text("None").tag("")
                    if let tag = viewModel.unlistedAssetTag { Text(verbatim: tag).tag(tag) }
                    ForEach(viewModel.assetChoices) { asset in
                        Text(verbatim: "\(asset.tag) · \(asset.name)").tag(asset.tag)
                    }
                }
            }
            TextField("Zone", text: $viewModel.zone)
                .focused($focused)
            TextField("Related assets", text: $viewModel.relatedAssets)
                .autocorrectionDisabled()
                .focused($focused)
        } header: {
            Text("Where")
        } footer: {
            Text("Related assets: tags separated by commas.")
        }
        .tint(Color.liteAccent)
    }
}
