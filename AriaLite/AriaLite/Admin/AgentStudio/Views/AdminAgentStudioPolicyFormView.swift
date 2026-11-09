//
//  AdminAgentStudioPolicyFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form della policy: limiti (vuoto = nessun limite), regole e regione dei dati.
//  Le liste e la matrice delle approvazioni restano come sono (si modificano sulla web).
//

import SwiftUI

struct AdminAgentStudioPolicyFormView: View {
    @State private var viewModel: AdminAgentStudioPolicyFormViewModel
    let onSaved: (AdminAgentStudioPolicy) -> Void

    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminAgentStudioPolicyFormViewModel, onSaved: @escaping (AdminAgentStudioPolicy) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    numberField("Cost ceiling (€)", text: $viewModel.costCeilingEur, decimal: true)
                    numberField("Max cost per run (€)", text: $viewModel.maxRunCostEur, decimal: true)
                    numberField("Max run time (seconds)", text: $viewModel.maxRunSeconds, decimal: false)
                    numberField("Max tokens per run", text: $viewModel.maxRunTokens, decimal: false)
                    numberField("Max runs per hour", text: $viewModel.maxRunsPerHour, decimal: false)
                } header: {
                    Text("Limits")
                } footer: {
                    Text("Leave a limit empty for no limit. Max run time is always required.")
                }
                Section("Rules") {
                    Toggle("Require safety review", isOn: $viewModel.requireSafetyReview)
                    Toggle("Require validator pass to enable", isOn: $viewModel.requireValidatorPassForEnable)
                    Toggle("AI classification fallback", isOn: $viewModel.classificationLlmFallback)
                }
                .tint(Color.liteAccent)
                Section {
                    TextField("Data region", text: $viewModel.dataRegion)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Saving creates a new policy version. Every run records the version it ran under.")
                }
                if let message = viewModel.validationMessage ?? viewModel.errorMessage {
                    Section {
                        AdminSectionNotice(text: message, isError: true)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit policy")
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
                            Task {
                                if let saved = await viewModel.save() {
                                    onSaved(saved)
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!viewModel.canSave)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.hasChanges)
        }
    }

    private func numberField(_ title: LocalizedStringKey, text: Binding<String>, decimal: Bool) -> some View {
        LabeledContent(title) {
            TextField(title, text: text, prompt: Text("No limit"))
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}
