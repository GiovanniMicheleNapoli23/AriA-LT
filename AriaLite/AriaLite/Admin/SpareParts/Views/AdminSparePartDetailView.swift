//
//  AdminSparePartDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un ricambio (pagina /spare-parts/{id} della web): intestazione con foto, quantità a
//  magazzino con la correzione rapida, stato di revisione (le decisioni nella barra in basso), dati, storico
//  prezzi. "Edit" apre il modulo.
//

import SwiftUI

struct AdminSparePartDetailView: View {
    @State private var viewModel: AdminSparePartDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(part: AdminSparePart, owner: AdminSparePartsViewModel) {
        _viewModel = State(initialValue: AdminSparePartDetailViewModel(part: part, owner: owner))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AdminSparePartHeader(part: viewModel.part, photoURL: viewModel.photoURL)
                if let failure = viewModel.failure { failureNote(failure) }
                if viewModel.showsReview {
                    AdminReviewBanner(stage: viewModel.reviewStage, message: viewModel.reviewMessage)
                }
                AdminSparePartStockCard(viewModel: viewModel)
                AdminSparePartDetailsCard(rows: viewModel.details, assetTags: viewModel.part.compatibleAssetTags,
                                          description: viewModel.part.description)
                AdminSparePartPriceHistoryCard(viewModel: viewModel)
            }
            .ariaReadableWidth()
            .padding(20)
        }
        .ariaBottomBar {
            if viewModel.showsReview {
                AdminReviewDecisionBar(actions: viewModel.reviewActions, running: viewModel.reviewing,
                                       error: viewModel.reviewError, perform: { viewModel.requestReview($0) })
            }
        }
        .liteBackground()
        .navigationTitle(Text(verbatim: viewModel.part.code))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
            }
            if viewModel.canDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isDeleting {
                        ProgressView()
                    } else {
                        Menu("More", systemImage: "ellipsis.circle") {
                            Button("Delete", systemImage: "trash", role: .destructive) { viewModel.showsDeleteConfirmation = true }
                        }
                    }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.editForm) { form in
            AdminSparePartFormView(viewModel: form)
        }
        .adminReviewConfirmation(isPresented: $viewModel.isConfirmingReview, action: viewModel.confirmingReview) { action in
            Task { await viewModel.review(action) }
        }
        .alert("Set quantity", isPresented: $viewModel.isSettingQuantity) {
            TextField("Quantity", text: $viewModel.quantityInput)
                .keyboardType(.numberPad)
            Button("Save") { viewModel.commitQuantity() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The new quantity in stock.")
        }
        .alert("Delete this spare part?", isPresented: $viewModel.showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(viewModel.part.name)” will be removed from your spare parts. This can't be undone.")
        }
        .alert("Couldn't delete the spare part", isPresented: $viewModel.isShowingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.deleteError ?? "")
        }
        .alert("Couldn't update the stock", isPresented: $viewModel.isShowingStockError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.stockError ?? "")
        }
    }

    /// La scheda è quella dell'elenco: l'aggiornamento non è arrivato (o il ricambio non c'è più).
    private func failureNote(_ failure: AdminSparePartsFailure) -> some View {
        Label {
            Text(verbatim: failure.message)
        } icon: {
            Image(systemName: failure.isForbidden ? "lock" : "exclamationmark.triangle")
        }
        .font(.footnote)
        .foregroundStyle(.orange)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
