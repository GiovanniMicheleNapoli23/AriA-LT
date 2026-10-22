//
//  AdminScenarioReviewFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form "Correct verdict": esito della procedura, voto facoltativo e problemi riscontrati.
//

import SwiftUI

struct AdminScenarioReviewFormView: View {
    @Bindable var viewModel: AdminScenarioReviewFormViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(viewModel.title).font(.headline)
                } footer: {
                    Text("Your outcome replaces Aria's verdict and updates the scenario's counts.")
                }
                Section("Outcome") {
                    Picker("Outcome", selection: $viewModel.outcome) {
                        ForEach(AdminScenarioReviewOutcome.allCases) { Label($0.label, systemImage: $0.systemImage).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Rating") {
                    Picker("Rating", selection: $viewModel.rating) {
                        Text("No rating").tag(0)
                        ForEach(1...5, id: \.self) { value in
                            Text(AdminScenarioFormat.stars(value) ?? "").tag(value)
                        }
                    }
                }
                Section("Issues") {
                    TextField("What went wrong? (optional)", text: $viewModel.issues, axis: .vertical)
                        .lineLimit(3...8)
                }
                if let message = viewModel.errorMessage {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Correct verdict")
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
            .interactiveDismissDisabled(viewModel.isSaving)
        }
    }
}
