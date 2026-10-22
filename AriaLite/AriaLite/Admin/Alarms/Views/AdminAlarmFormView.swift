//
//  AdminAlarmFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di modifica di un allarme, in uno sheet. Un Form di sistema: tiene il campo attivo sopra la
//  tastiera anche su iPhone in orizzontale. Controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminAlarmFormView: View {
    @Bindable var viewModel: AdminAlarmFormViewModel
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
                location
                AdminAlarmListSection(title: "Typical causes", addTitle: "Add cause", items: $viewModel.causes,
                                      add: viewModel.addCause)
                AdminAlarmListSection(title: "Resolution steps", addTitle: "Add step", items: $viewModel.steps,
                                      add: viewModel.addStep)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Edit alarm")
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
            LabeledContent("Code") { Text(verbatim: viewModel.alarm.code).font(.body.monospaced()) }
            TextField("Description", text: $viewModel.description, axis: .vertical)
                .lineLimit(2...8)
            Picker("Status", selection: $viewModel.statusKey) {
                ForEach(viewModel.statusOptions, id: \.key) { option in
                    Text(verbatim: option.label).tag(option.key)
                }
            }
        } footer: {
            Text("The description is required. The code can't be changed.")
        }
    }

    private var location: some View {
        Section("Where it appears") {
            TextField("Asset tag", text: $viewModel.assetTag)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Category", text: $viewModel.category)
            TextField("Zone", text: $viewModel.zone)
            TextField("HMI page", text: $viewModel.hmiPage)
        }
    }
}
