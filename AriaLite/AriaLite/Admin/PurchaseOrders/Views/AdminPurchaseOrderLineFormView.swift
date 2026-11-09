//
//  AdminPurchaseOrderLineFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo per aggiungere una riga a un ordine (sheet): ricambio dall'elenco o codice libero, quantità, costo unitario, note. Un Form di sistema, che tiene il campo attivo sopra la tastiera anche su iPhone in orizzontale.
//

import SwiftUI

struct AdminPurchaseOrderLineFormView: View {
    @Bindable var viewModel: AdminPurchaseOrderLineFormViewModel
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
                partSection
                amountsSection
                Section("Notes") {
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle("Add line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.isSaving)
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
                Button("Add") {
                    Task { if await viewModel.save() { dismiss() } }
                }
                .disabled(!viewModel.canSave)
            }
        }
    }

    private var partSection: some View {
        Section {
            NavigationLink {
                AdminPurchaseOrderLinePartPicker(viewModel: viewModel)
            } label: {
                LabeledContent("Spare part") {
                    if let title = viewModel.selectedPartTitle {
                        Text(verbatim: title).lineLimit(2).multilineTextAlignment(.trailing)
                    } else {
                        Text("Choose").foregroundStyle(.secondary)
                    }
                }
            }
            TextField("Part code", text: $viewModel.partCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            if viewModel.selectedPart != nil {
                Button("Clear selection", role: .destructive) { viewModel.clearSelection() }
            }
        } header: {
            Text("Part")
        } footer: {
            Text("Choose a spare part, or type a part code that isn't in the list.")
        }
    }

    private var amountsSection: some View {
        Section {
            LabeledContent("Quantity") {
                TextField(text: $viewModel.quantity) { Text(verbatim: "0") }
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            if let error = viewModel.quantityError { errorText(error) }
            LabeledContent("Unit cost") {
                HStack(spacing: 6) {
                    TextField("Optional", text: $viewModel.unitCost)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(verbatim: viewModel.currencyCode).foregroundStyle(.secondary)
                }
            }
            if let error = viewModel.unitCostError { errorText(error) }
        } header: {
            Text("Quantity and cost")
        } footer: {
            Text("The quantity is required. Choosing a spare part fills in its unit price.")
        }
    }

    private func errorText(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(.red)
    }
}
