//
//  AdminWorkOrderStepReportSheet.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il risultato di un passo registrato dall'admin: fatto o non fatto e la nota (obbligatoria per
//  "non fatto"). Le foto dell'operatore restano.
//

import SwiftUI

struct AdminWorkOrderStepReportSheet: View {
    @Bindable var viewModel: AdminWorkOrderStepReportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(verbatim: "\(viewModel.step.number). \(viewModel.step.text)")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Picker("Result", selection: $viewModel.status) {
                        Text(AdminWorkOrderStepStatus.done.localized).tag(AdminWorkOrderStepStatus.done)
                        Text(AdminWorkOrderStepStatus.notDone.localized).tag(AdminWorkOrderStepStatus.notDone)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField(viewModel.isNoteRequired ? LocalizedStringKey("Why wasn't it done?")
                                                       : LocalizedStringKey("Optional note"),
                              text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Note")
                } footer: {
                    if viewModel.isTooLong {
                        Text("The note is too long (2000 characters at most).").foregroundStyle(.red)
                    } else if viewModel.isNoteRequired {
                        Text("A note is required when a step was not done.")
                    }
                }
                if let message = viewModel.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(String(localized: "Step \(viewModel.step.number)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await viewModel.save() } }
                            .disabled(!viewModel.canSave)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .onChange(of: viewModel.isDone) { _, done in
                if done { dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
