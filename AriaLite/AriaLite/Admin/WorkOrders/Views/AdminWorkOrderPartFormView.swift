//
//  AdminWorkOrderPartFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo sheet di un ricambio usato: scelta dal magazzino (con giacenza) o codice scritto, quantità e costo
//  unitario. In modifica il ricambio resta quello, cambiano solo quantità e costo.
//

import SwiftUI

struct AdminWorkOrderPartFormView: View {
    @Bindable var viewModel: AdminWorkOrderPartFormViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    private enum Field: Hashable { case code, quantity, unitCost }

    var body: some View {
        NavigationStack {
            Form {
                if let message = viewModel.errorMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                }
                partSection
                Section {
                    LabeledContent("Quantity") {
                        TextField("1" as String, text: $viewModel.quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focused, equals: .quantity)
                    }
                    LabeledContent("Unit cost") {
                        HStack(spacing: 4) {
                            TextField("0" as String, text: $viewModel.unitCost)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focused, equals: .unitCost)
                            Text(verbatim: AdminWorkOrderCostFormat.currencyCode).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    footer
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await viewModel.loadChoices() }
        }
        .interactiveDismissDisabled(viewModel.hasChanges || viewModel.isSaving)
    }

    @ViewBuilder
    private var partSection: some View {
        Section {
            if viewModel.isCreating {
                if !viewModel.partsUnavailable {
                    NavigationLink {
                        AdminWorkOrderChoiceList(title: String(localized: "Part"), choices: viewModel.partChoices,
                                                 selection: viewModel.selectedPart?.id, onSelect: viewModel.selectPart)
                    } label: {
                        LabeledContent("Part", value: viewModel.partLabel)
                    }
                }
                if viewModel.selectedPart == nil {
                    TextField("Part code", text: $viewModel.partCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .code)
                }
            } else {
                LabeledContent("Part", value: viewModel.partLabel)
            }
            if let stock = viewModel.stockLabel {
                LabeledContent("Stock", value: stock)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let message = viewModel.validationMessage, viewModel.hasChanges {
                Text(message).foregroundStyle(.red)
            } else if let preview = viewModel.linePreview {
                Text(preview)
            }
            if let warning = viewModel.stockWarning {
                Text(warning).foregroundStyle(.orange)
            }
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
}
