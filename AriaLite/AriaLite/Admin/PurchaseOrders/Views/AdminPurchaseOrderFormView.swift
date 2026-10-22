//
//  AdminPurchaseOrderFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di un ordine di acquisto (foglio), per crearlo o modificarne la testata. Un Form di sistema:
//  tiene il campo attivo sopra la tastiera anche su iPhone in orizzontale. Controlli e salvataggio sono
//  nel view model.
//

import SwiftUI

struct AdminPurchaseOrderFormView: View {
    @Bindable var viewModel: AdminPurchaseOrderFormViewModel
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
                dates
                Section("Shipping address") {
                    TextField("Shipping address", text: $viewModel.shippingAddress, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("Notes") {
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(2...8)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle(Text(verbatim: viewModel.navigationTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
            .task { await viewModel.lookups.refreshIfStale() }
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
            TextField("Title", text: $viewModel.title)
            Picker("Vendor", selection: $viewModel.vendorId) {
                Text("None").tag(String?.none)
                ForEach(viewModel.lookups.sortedVendors) { vendor in
                    Text(verbatim: vendor.displayName).tag(Optional(vendor.id))
                }
                if viewModel.hasUnlistedVendor, let id = viewModel.vendorId {
                    Text("Current vendor").tag(Optional(id))
                }
            }
            plant
        } footer: {
            Text("The title is required.")
        }
    }

    @ViewBuilder
    private var plant: some View {
        if viewModel.showsPlantPicker {
            Picker("Plant", selection: $viewModel.plantId) {
                if viewModel.plantId == nil { Text("Choose a plant").tag(String?.none) }
                ForEach(viewModel.plants) { plant in
                    Text(verbatim: plant.name).tag(Optional(plant.id))
                }
                if viewModel.hasUnlistedPlant, let id = viewModel.plantId {
                    Text("Current plant").tag(Optional(id))
                }
            }
        } else if let name = viewModel.plantName {
            LabeledContent("Plant") { Text(verbatim: name) }
        }
    }

    private var dates: some View {
        Section {
            Toggle("Order date", isOn: $viewModel.hasOrderDate.animation())
            if viewModel.hasOrderDate {
                DatePicker("Date", selection: $viewModel.orderDate, displayedComponents: .date)
                    .accessibilityLabel("Order date")
            }
            Toggle("Expected delivery", isOn: $viewModel.hasExpectedDelivery.animation())
            if viewModel.hasExpectedDelivery {
                DatePicker("Date", selection: $viewModel.expectedDelivery, displayedComponents: .date)
                    .accessibilityLabel("Expected delivery")
            }
        } header: {
            Text("Dates")
        } footer: {
            if let error = viewModel.dateError {
                Text(verbatim: error).foregroundStyle(.red)
            }
        }
    }
}
