//
//  AdminVendorDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un fornitore (pagina /vendors/{id} della web): intestazione, contatti, note e date.
//  "Edit" apre il modulo; il cestino chiede conferma, poi elimina e torna all'elenco.
//

import SwiftUI

struct AdminVendorDetailView: View {
    @State private var viewModel: AdminVendorDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(vendor: AdminVendor, owner: AdminVendorsViewModel) {
        _viewModel = State(initialValue: AdminVendorDetailViewModel(vendor: vendor, owner: owner))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminVendorHeader(vendor: viewModel.vendor, rating: viewModel.ratingValue)
                if let failure = viewModel.failure { AdminVendorFailureNote(failure: failure) }
                if !viewModel.contactItems.isEmpty { AdminVendorContactCard(items: viewModel.contactItems) }
                if viewModel.showsNotesCard {
                    AdminVendorNotesCard(notes: viewModel.vendor.notes, dateRows: viewModel.dateRows)
                }
            }
            .ariaReadableWidth()
            .padding(20)
        }
        .liteBackground()
        .navigationTitle(Text(verbatim: viewModel.vendor.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isDeleting {
                    ProgressView()
                } else {
                    Button("Delete", systemImage: "trash", role: .destructive) { viewModel.showsDeleteConfirmation = true }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.editForm) { form in
            AdminVendorFormView(viewModel: form)
        }
        .confirmationDialog("Delete this vendor?", isPresented: $viewModel.showsDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(viewModel.vendor.title)” will be removed from your vendors. This can't be undone.")
        }
        .alert("Couldn't delete the vendor", isPresented: $viewModel.isShowingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.deleteError ?? "")
        }
    }
}
