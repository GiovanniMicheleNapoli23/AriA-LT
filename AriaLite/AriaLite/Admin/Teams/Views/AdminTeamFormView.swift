//
//  AdminTeamFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di una squadra, nuova o da modificare, in uno sheet. Un Form di sistema: tiene il campo attivo sopra
//  la tastiera anche su iPhone in orizzontale. Controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminTeamFormView: View {
    @Bindable var viewModel: AdminTeamFormViewModel
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
                    TextField("Name", text: $viewModel.name)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...6)
                } footer: {
                    Text("Name is required.")
                }
                Section("Plant") {
                    Picker("Plant", selection: $viewModel.plantId) {
                        Text("No plant").tag(String?.none)
                        ForEach(viewModel.plants) { plant in
                            Text(verbatim: plant.name).tag(Optional(plant.id))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle(Text(verbatim: viewModel.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
        }
    }
}
