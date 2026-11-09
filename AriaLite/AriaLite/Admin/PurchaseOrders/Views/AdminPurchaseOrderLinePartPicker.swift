//
//  AdminPurchaseOrderLinePartPicker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'elenco dei ricambi dello stabilimento per scegliere quello di una riga, con ricerca per codice, nome e codice produttore. Scegliere un ricambio compila codice e costo unitario e torna al modulo.
//

import SwiftUI

struct AdminPurchaseOrderLinePartPicker: View {
    @Bindable var viewModel: AdminPurchaseOrderLineFormViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(viewModel.filteredParts) { part in
                Button {
                    viewModel.select(part)
                    dismiss()
                } label: {
                    row(part)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay { placeholder }
        .scrollContentBackground(.hidden)
        .liteBackground()
        .navigationTitle("Spare parts")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search by code or name")
        .task { await viewModel.loadParts() }
    }

    private func row(_ part: AdminSparePart) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: part.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(verbatim: part.code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let price = part.unitPrice {
                Text(verbatim: AdminPurchaseOrderDetailFormat.money(price))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if viewModel.selectedPart?.id == part.id {
                Image(systemName: "checkmark").foregroundStyle(Color.liteAccent)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var placeholder: some View {
        if viewModel.parts.isLoading && viewModel.parts.parts.isEmpty {
            ProgressView()
        } else if let message = viewModel.parts.failureMessage, viewModel.parts.parts.isEmpty {
            ContentUnavailableView("Spare parts couldn't be loaded", systemImage: "exclamationmark.triangle",
                                   description: Text(verbatim: message))
        } else if viewModel.filteredParts.isEmpty {
            if viewModel.searchText.isEmpty {
                ContentUnavailableView("No spare parts", systemImage: "shippingbox",
                                       description: Text("Type a part code in the form instead."))
            } else {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }
}
