//
//  AdminAlarmWorkOrderFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Create work order" dalla diagnosi, in uno sheet: i campi arrivano precompilati dall'ordine suggerito e
//  l'ordine si crea solo con "Create". Un Form di sistema; la logica sta nel view model.
//

import SwiftUI

struct AdminAlarmWorkOrderFormView: View {
    @Bindable var viewModel: AdminAlarmWorkOrderFormViewModel
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
                    TextField("Title", text: $viewModel.title, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Description", text: $viewModel.details, axis: .vertical)
                        .lineLimit(3...10)
                } footer: {
                    Text("Prefilled from the diagnosis. Check it before creating the work order.")
                }
                Section {
                    Picker("Priority", selection: $viewModel.priority) {
                        ForEach(viewModel.priorityOptions, id: \.key) { option in
                            Text(verbatim: option.label).tag(option.key)
                        }
                    }
                    Picker("Plant", selection: $viewModel.plantId) {
                        ForEach(viewModel.plants) { plant in
                            Text(verbatim: plant.name).tag(Optional(plant.id))
                        }
                    }
                    TextField("Asset tag", text: $viewModel.assetTag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if viewModel.stepCount > 0 {
                    Section {
                        Toggle("Use the repair steps as the procedure", isOn: $viewModel.includesSteps)
                            .tint(Color.liteAccent)
                    } footer: {
                        Text("\(viewModel.stepCount) steps from the diagnosis.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("New work order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task { if await viewModel.create() { dismiss() } }
                        }
                        .disabled(!viewModel.canCreate)
                    }
                }
            }
            .disabled(viewModel.isSaving)
        }
    }
}
