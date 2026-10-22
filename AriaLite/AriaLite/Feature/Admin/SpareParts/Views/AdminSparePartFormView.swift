//
//  AdminSparePartFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di un ricambio, nuovo o da modificare, in uno sheet. Un Form di sistema: tiene il campo
//  attivo sopra la tastiera anche su iPhone in orizzontale. Controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminSparePartFormView: View {
    @Bindable var viewModel: AdminSparePartFormViewModel
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
                details
                stock
                purchasing
                storage
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle(Text(verbatim: viewModel.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
            .task { await viewModel.loadVendors() }
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

    // MARK: Sezioni

    private var identity: some View {
        Section {
            TextField("Code", text: $viewModel.code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            TextField("Name", text: $viewModel.name)
            Picker("Category", selection: $viewModel.category) {
                Text("None").tag(AdminSparePartCategory?.none)
                ForEach(viewModel.categoryChoices, id: \.self) { category in
                    Text(verbatim: category.localized).tag(Optional(category))
                }
            }
            Picker("Status", selection: $viewModel.status) {
                ForEach(viewModel.statusChoices, id: \.self) { status in
                    Text(verbatim: status.localized).tag(status)
                }
            }
        } footer: {
            Text("Code and name are required.")
        }
    }

    private var details: some View {
        Section {
            TextField("Manufacturer", text: $viewModel.manufacturer)
            TextField("Part number", text: $viewModel.partNumber)
                .autocorrectionDisabled()
            TextField("Description", text: $viewModel.description, axis: .vertical)
                .lineLimit(2...6)
            TextField("Compatible assets", text: $viewModel.assetTags, axis: .vertical)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        } header: {
            Text("Details")
        } footer: {
            Text("Separate compatible asset tags with commas.")
        }
    }

    private var stock: some View {
        Section {
            Toggle("Non-stock item", isOn: $viewModel.nonStock)
            LabeledContent("Stock quantity") {
                TextField(text: $viewModel.stockQuantity) { Text(verbatim: "0") }
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Minimum quantity") {
                TextField("None", text: $viewModel.minQuantity)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            TextField("Unit (e.g. pcs, m, kg)", text: $viewModel.unit)
                .autocorrectionDisabled()
        } header: {
            Text("Stock")
        } footer: {
            Text("A part is low on stock when its quantity drops to the minimum.")
        }
    }

    private var purchasing: some View {
        Section("Purchasing") {
            LabeledContent("Unit price") {
                TextField("None", text: $viewModel.unitPrice)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            Picker("Vendor", selection: $viewModel.vendorId) {
                Text("None").tag(String?.none)
                ForEach(viewModel.vendors.sorted) { vendor in
                    Text(verbatim: vendor.displayName).tag(Optional(vendor.id))
                }
                if viewModel.hasUnlistedVendor, let id = viewModel.vendorId {
                    Text("Current vendor").tag(Optional(id))
                }
            }
            if viewModel.vendors.isLoading && viewModel.vendors.vendors.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading vendors...").foregroundStyle(.secondary)
                }
                .font(.footnote)
            } else if viewModel.vendors.failure != nil, viewModel.vendors.vendors.isEmpty {
                Text("Vendors couldn't be loaded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var storage: some View {
        Section("Storage") {
            TextField("Location", text: $viewModel.location)
            TextField("Barcode", text: $viewModel.barcode)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
