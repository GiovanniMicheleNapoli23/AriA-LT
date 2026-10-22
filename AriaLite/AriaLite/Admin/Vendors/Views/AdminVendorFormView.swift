//
//  AdminVendorFormView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di un fornitore, nuovo o da modificare, in uno sheet. Un Form di sistema: tiene il campo
//  attivo sopra la tastiera anche su iPhone in orizzontale. Controlli e salvataggio sono nel view model.
//

import SwiftUI

struct AdminVendorFormView: View {
    @Bindable var viewModel: AdminVendorFormViewModel
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
                rating
                contact
                location
                notes
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .liteBackground()
            .navigationTitle(Text(verbatim: viewModel.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .disabled(viewModel.isSaving)
            .interactiveDismissDisabled(viewModel.hasChanges)
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
            TextField("Name", text: $viewModel.name)
            TextField("Company name", text: $viewModel.companyName)
            HStack {
                TextField("Type (e.g. Parts, Services)", text: $viewModel.vendorType)
                if !viewModel.typeSuggestions.isEmpty {
                    Menu {
                        ForEach(viewModel.typeSuggestions, id: \.self) { type in
                            Button(type) { viewModel.vendorType = type }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .accessibilityLabel(Text("Existing types"))
                }
            }
        } footer: {
            Text("Name is required.")
        }
    }

    private var rating: some View {
        Section {
            Toggle("Rated", isOn: $viewModel.hasRating)
            if viewModel.hasRating {
                Stepper(value: $viewModel.rating, in: viewModel.ratingRange, step: viewModel.ratingStep) {
                    LabeledContent("Rating") {
                        AdminVendorRatingView(value: viewModel.rating)
                    }
                }
            }
        } footer: {
            Text("From 0 to 5, in half points.")
        }
    }

    private var contact: some View {
        Section("Contact") {
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Phone", text: $viewModel.phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
            TextField("Website", text: $viewModel.website)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var location: some View {
        Section("Address") {
            TextField("Street address", text: $viewModel.address)
                .textContentType(.fullStreetAddress)
            TextField("City", text: $viewModel.city)
                .textContentType(.addressCity)
            TextField("Country", text: $viewModel.country)
                .textContentType(.countryName)
        }
    }

    private var notes: some View {
        Section("Notes") {
            TextField("Notes", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...8)
        }
    }
}
