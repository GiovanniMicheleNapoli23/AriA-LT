//
//  AdminPurchaseOrdersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Purchase Orders, come la pagina /purchase-orders della web: filtri e riepilogo in alto,
//  ricerca, una scheda per ordine, dettaglio a tocco e "+" per crearne uno nuovo.
//

import SwiftUI

struct AdminPurchaseOrdersView: View {
    @Bindable var viewModel: AdminPurchaseOrdersViewModel

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AdminPurchaseOrderFilterBar(viewModel: viewModel)
                        .padding(.top, 8)
                    errorPill
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Purchase Orders")
            .navigationDestination(for: AdminPurchaseOrderRoute.self) { destination($0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New purchase order", systemImage: "plus") { viewModel.startCreating() }
                        .disabled(!viewModel.canCreate)
                        .accessibilityHint(viewModel.createDisabledReason ?? "")
                }
            }
            .searchable(text: $viewModel.query, prompt: Text("Title, vendor, notes..."))
            .sheet(item: $viewModel.form) { form in
                AdminPurchaseOrderFormView(viewModel: form)
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let placeholder = viewModel.placeholder {
            AdminPurchaseOrderPlaceholder(placeholder: placeholder,
                                          retry: { Task { await viewModel.refresh() } },
                                          clearFilters: { withAnimation(.snappy) { viewModel.clearFilters() } })
        } else {
            AdminPurchaseOrderSummaryGrid(tiles: viewModel.summaryTiles)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            LazyVStack(spacing: 8) {
                ForEach(viewModel.rows) { info in
                    NavigationLink(value: AdminPurchaseOrderRoute.order(info.id)) {
                        AdminPurchaseOrderRow(info: info)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)

            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: AdminPurchaseOrderRoute) -> some View {
        switch route {
        case .order(let id):
            if let detail = viewModel.detailViewModel(forId: id) {
                AdminPurchaseOrderDetailView(viewModel: detail)
            } else {
                ContentUnavailableView("Not available", systemImage: "questionmark.folder",
                                       description: Text("This item is no longer in the list. Pull to refresh and try again."))
                    .liteBackground()
            }
        }
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.refreshFailed {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
                Text("Couldn't refresh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await viewModel.refresh() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
}
