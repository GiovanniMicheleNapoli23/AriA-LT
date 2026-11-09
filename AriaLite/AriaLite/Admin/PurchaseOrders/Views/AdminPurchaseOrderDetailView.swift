//
//  AdminPurchaseOrderDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un ordine di acquisto, come la pagina /purchase-orders/{id} della web: testata, dati, righe e, in basso, le azioni dello stato. "Edit" e il menu (elimina) stanno nella barra. Logica, conferme e chiamate sono nel view model; eliminato l'ordine, la vista torna indietro.
//

import SwiftUI

struct AdminPurchaseOrderDetailView: View {
    @Bindable var viewModel: AdminPurchaseOrderDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isUnavailable {
                    AdminPurchaseOrderDetailUnavailable(
                        message: viewModel.failure?.message
                            ?? String(localized: "This purchase order isn't on the server, so it can't be shown or changed."))
                } else {
                    AdminPurchaseOrderDetailHeader(viewModel: viewModel)
                    if let failure = viewModel.failure { AdminPurchaseOrderDetailFailureNote(failure: failure) }
                    AdminPurchaseOrderDetailLinesCard(viewModel: viewModel)
                    AdminPurchaseOrderDetailInfoCard(rows: viewModel.infoRows)
                }
            }
            .ariaReadableWidth()
            .padding(20)
        }
        .liteBackground()
        .navigationTitle("Purchase order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasPrimaryActions { AdminPurchaseOrderDetailActions(viewModel: viewModel) }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .sheet(item: $viewModel.editForm) { form in
            AdminPurchaseOrderFormView(viewModel: form)
        }
        .sheet(item: $viewModel.lineForm) { form in
            AdminPurchaseOrderLineFormView(viewModel: form)
        }
        .alert(
            Text(verbatim: viewModel.pendingConfirmation?.title ?? ""),
            isPresented: $viewModel.isConfirming,
            presenting: viewModel.pendingConfirmation
        ) { confirmation in
            Button(confirmation.confirmLabel, role: confirmation.isDestructive ? .destructive : nil) {
                Task { await viewModel.confirm(confirmation) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { confirmation in
            Text(verbatim: confirmation.message)
        }
        .alert("Something went wrong", isPresented: $viewModel.isShowingActionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.actionError ?? "")
        }
        .onChange(of: viewModel.didDelete) { _, deleted in
            if deleted { dismiss() }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if viewModel.isRefreshing {
            ToolbarItem(placement: .topBarTrailing) { ProgressView() }
        }
        if viewModel.canEdit {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { viewModel.startEditing() }
                    .disabled(viewModel.isBusy)
            }
        }
        if viewModel.canDelete {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Delete", systemImage: "trash", role: .destructive) { viewModel.ask(.delete) }
                        .disabled(viewModel.isBusy)
                }
            }
        }
    }
}
