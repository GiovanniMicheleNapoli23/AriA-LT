//
//  AdminWorkOrderCostExtraFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo sheet di un costo aggiuntivo: descrizione, importo e categoria.
//

import SwiftUI

struct AdminWorkOrderCostExtraFormView: View {
    @Bindable var viewModel: AdminWorkOrderCostExtraFormViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    private enum Field: Hashable { case description, value }

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.errorMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                }
                Section {
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused, equals: .description)
                    LabeledContent("Amount") {
                        HStack(spacing: 4) {
                            TextField("0" as String, text: $viewModel.value)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focused, equals: .value)
                            Text(verbatim: viewModel.currencyCode).foregroundStyle(.secondary)
                        }
                    }
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(AdminWorkOrderCostCategory.allCases, id: \.self) { Text($0.localized).tag($0) }
                    }
                } footer: {
                    if let message = viewModel.validationMessage, viewModel.hasChanges {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Additional Cost")
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
                            focused = nil
                            Task { if await viewModel.save() { dismiss() } }
                        }
                        .disabled(!viewModel.canSave)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(viewModel.hasChanges || viewModel.isSaving)
    }
}
