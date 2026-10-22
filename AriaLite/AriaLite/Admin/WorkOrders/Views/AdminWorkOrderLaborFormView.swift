//
//  AdminWorkOrderLaborFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo sheet per registrare manodopera: persona (dall'elenco o scritta), inizio, minuti e tariffa oraria.
//  Controlli e salvataggio in AdminWorkOrderLaborFormViewModel.
//

import SwiftUI

struct AdminWorkOrderLaborFormView: View {
    @Bindable var viewModel: AdminWorkOrderLaborFormViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    private enum Field: Hashable { case worker, minutes, rate }

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.errorMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                }
                Section {
                    if !viewModel.workersUnavailable {
                        NavigationLink {
                            AdminWorkOrderChoiceList(title: String(localized: "Worker"), choices: viewModel.workerChoices,
                                                     selection: viewModel.workerUserId, onSelect: viewModel.selectWorker)
                        } label: {
                            LabeledContent("Choose person", value: viewModel.workerLabel)
                        }
                    }
                    TextField("Worker name", text: $viewModel.worker)
                        .textContentType(.name)
                        .focused($focused, equals: .worker)
                        .onChange(of: viewModel.worker) { viewModel.workerTextChanged() }
                }
                Section {
                    DatePicker("Started", selection: $viewModel.startedAt)
                    LabeledContent("Duration") {
                        numberField(String(localized: "Minutes"), text: $viewModel.minutes, field: .minutes, keyboard: .numberPad, suffix: "min")
                    }
                    LabeledContent("Hourly rate") {
                        numberField("0", text: $viewModel.hourlyRate, field: .rate, keyboard: .decimalPad,
                                    suffix: AdminWorkOrderCostFormat.currencyCode)
                    }
                } footer: {
                    footer
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Log Labor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await viewModel.loadChoices() }
        }
        .interactiveDismissDisabled(viewModel.hasChanges || viewModel.isSaving)
    }

    @ViewBuilder
    private var footer: some View {
        if let message = viewModel.validationMessage, viewModel.hasChanges {
            Text(message).foregroundStyle(.red)
        } else if let preview = viewModel.costPreview {
            Text(preview)
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
                    focused = nil
                    Task { if await viewModel.save() { dismiss() } }
                }
                .disabled(!viewModel.canSave)
            }
        }
    }

    private func numberField(_ placeholder: String, text: Binding<String>, field: Field,
                             keyboard: UIKeyboardType, suffix: String) -> some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .focused($focused, equals: field)
            Text(verbatim: suffix).foregroundStyle(.secondary)
        }
    }
}
