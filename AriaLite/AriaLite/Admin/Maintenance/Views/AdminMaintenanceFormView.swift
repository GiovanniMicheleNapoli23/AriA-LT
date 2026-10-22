//
//  AdminMaintenanceFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio per creare o modificare un piano: una sola scroll view di schede (piano, programmazione,
//  passi, ricambi, descrizione). "Save" sta sempre in alto: va bene anche in orizzontale con la tastiera aperta.
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    identityCard
                    AdminMaintenanceFormScheduleCard(viewModel: viewModel, focus: $focused)
                    AdminMaintenanceFormListsCard(viewModel: viewModel, focus: $focused)
                    if let message = viewModel.errorMessage {
                        AdminSectionNotice(text: message, isError: true)
                    } else if let message = viewModel.validationMessage {
                        AdminSectionNotice(text: message, systemImage: "info.circle")
                    }
                }
                .padding(20)
                .ariaReadableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
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

    // MARK: Schede

    private var identityCard: some View {
        AdminCard(title: "Plan", systemImage: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 12) {
                AdminMaintenanceTextField(title: "Name", text: $viewModel.name, prompt: "e.g. Monthly bearing check",
                                          focus: $focused)
                AdminMaintenanceTextField(title: "Asset tag", text: $viewModel.assetTag, prompt: "e.g. M-101",
                                          isMonospaced: true, focus: $focused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                if !viewModel.assetChoices.isEmpty {
                    AdminMaintenanceMenuRow(title: "Choose asset", value: viewModel.assetTag.isEmpty ? "—" : viewModel.assetTag) {
                        Button("None") { viewModel.chooseAsset(nil) }
                        ForEach(viewModel.assetChoices) { asset in
                            Button("\(asset.tag) · \(asset.name)") { viewModel.chooseAsset(asset) }
                        }
                    }
                }
                AdminMaintenanceTextField(title: "Related assets", text: $viewModel.relatedAssets,
                                          prompt: "Tags separated by commas", focus: $focused)
                    .autocorrectionDisabled()
                if !viewModel.plants.isEmpty {
                    AdminMaintenanceMenuRow(title: "Plant", value: plantName) {
                        Picker("Plant", selection: $viewModel.plantId) {
                            if viewModel.plantId == nil { Text("Select").tag(String?.none) }
                            ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                }
                AdminMaintenanceTextField(title: "Category", text: $viewModel.category, focus: $focused)
                AdminMaintenanceTextField(title: "Zone", text: $viewModel.zone, focus: $focused)
                AdminMaintenanceMenuRow(title: "Status", value: viewModel.statusLabel(viewModel.status)) {
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(viewModel.statusOptions, id: \.self) { Text(viewModel.statusLabel($0)).tag($0) }
                    }
                }
            }
        }
    }

    private var plantName: String {
        guard let id = viewModel.plantId else { return String(localized: "Select") }
        return viewModel.plants.first { $0.id == id }?.name ?? id
    }
}
