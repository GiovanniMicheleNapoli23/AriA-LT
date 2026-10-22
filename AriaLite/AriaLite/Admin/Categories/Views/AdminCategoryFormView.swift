//
//  AdminCategoryFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di una categoria, nuova o da modificare, in uno sheet. Un Form di sistema, come quello dei
//  fornitori. Controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminCategoryFormView: View {
    @Bindable var viewModel: AdminCategoryFormViewModel
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
                identity
                appearance
                plant
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle(Text(verbatim: viewModel.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if viewModel.isSaving {
                ProgressView()
            } else {
                Button("Save") {
                    Task { if await viewModel.save() { dismiss() } }
                }
                .disabled(!viewModel.canSave)
            }
        }
    }

    private var identity: some View {
        Section {
            TextField("Name", text: $viewModel.name)
            HStack {
                TextField("Entity type", text: $viewModel.entityType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !viewModel.entityTypeSuggestions.isEmpty {
                    Menu {
                        ForEach(viewModel.entityTypeSuggestions, id: \.self) { type in
                            Button(type) { viewModel.entityType = type }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .accessibilityLabel(Text("Existing entity types"))
                }
            }
            TextField("Description", text: $viewModel.description, axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Text("Category")
        } footer: {
            Text("Name and entity type are required.")
        }
    }

    private var appearance: some View {
        Section {
            Toggle("Color", isOn: $viewModel.hasColor)
            if viewModel.hasColor {
                ColorPicker("Color", selection: $viewModel.color, supportsOpacity: false)
            }
            HStack {
                TextField("Icon (SF Symbol name)", text: $viewModel.icon)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Image(systemName: AdminCategoryIcon.symbolName(for: viewModel.icon))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        } footer: {
            if viewModel.iconIsValid {
                Text("Optional. Leave the icon empty for the default one.")
            } else {
                Text("This isn't a valid symbol name.")
                    .foregroundStyle(.red)
            }
        }
    }

    private var plant: some View {
        Section {
            Picker("Plant", selection: $viewModel.plantId) {
                // In creazione lo stabilimento è obbligatorio: "tutti" non si può scegliere.
                if viewModel.isEditing {
                    Text("All plants").tag(String?.none)
                }
                ForEach(viewModel.plants) { plant in
                    Text(plant.name).tag(Optional(plant.id))
                }
            }
        } footer: {
            Text(viewModel.isEditing
                ? "Choose which plant the category belongs to."
                : "A new category belongs to one plant.")
        }
    }
}
