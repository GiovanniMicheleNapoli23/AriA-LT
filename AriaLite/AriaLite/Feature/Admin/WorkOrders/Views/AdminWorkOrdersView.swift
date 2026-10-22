//
//  AdminWorkOrdersView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli ordini di lavoro dell'azienda, come la pagina /work-orders della web: lista, dettaglio, creazione e modifica.
//  Qui solo la lista: chip dei filtri, ricerca, pull-to-refresh e altre pagine scorrendo. Tutta la logica è
//  in AdminWorkOrdersViewModel.
//

import SwiftUI

struct AdminWorkOrdersView: View {
    @Bindable var viewModel: AdminWorkOrdersViewModel

    init(viewModel: AdminWorkOrdersViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    AdminWorkOrderFilterBar(statusGroup: viewModel.statusGroup, priority: viewModel.priority,
                                            onSelectGroup: viewModel.select, onTogglePriority: viewModel.toggle)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    errorPill
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Work Orders")
            .navigationDestination(for: AdminWorkOrderRoute.self) { route in
                AdminWorkOrderDetailView(viewModel: viewModel.detailModel(for: route.order))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Work Order", systemImage: "plus") { viewModel.startCreating() }
                        .disabled(viewModel.isForbidden)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Search title, asset or zone"))
            .sheet(item: $viewModel.createForm) { form in
                AdminWorkOrderFormView(viewModel: form)
            }
        }
        .task(id: viewModel.backend.activePlantId) { await viewModel.loadIfNeeded() }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                failure(message)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        } else if viewModel.rows.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No work orders", systemImage: "wrench.and.screwdriver",
                                       description: Text("Nothing matches these filters."))
                    .padding(.top, 40)
            }
        } else {
            rows
        }
    }

    private var rows: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.rows) { item in
                NavigationLink(value: AdminWorkOrderRoute(order: item.order)) {
                    AdminWorkOrderRow(item: item)
                }
                .buttonStyle(.plain)
                .onAppear { viewModel.loadMoreIfNeeded(after: item) }
            }
            footer
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    /// Altre pagine: si caricano scorrendo; il pulsante serve quando la ricerca nasconde l'ultima riga.
    @ViewBuilder
    private var footer: some View {
        if viewModel.isLoadingMore {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 16)
        } else if viewModel.canLoadMore {
            Button("Load more") { viewModel.loadMore() }
                .ariaGlassButtonStyle()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }

    /// Mai arrivata la lista: si dice perché, con "Retry" se riprovare ha senso (non per un 403).
    private func failure(_ message: String) -> some View {
        VStack(spacing: 14) {
            if viewModel.isForbidden {
                ContentUnavailableView("No access to work orders", systemImage: "lock", description: Text(message))
            } else {
                ContentUnavailableView("Can't load work orders", systemImage: "wifi.exclamationmark",
                                       description: Text(message))
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .ariaGlassButtonStyle()
            }
        }
        .padding(.top, 40)
    }

    /// Lista già a schermo ma l'ultimo caricamento è fallito: una riga sottile col motivo.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.hasLoaded, let message = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isForbidden ? "lock" : "wifi.exclamationmark").foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !viewModel.isForbidden {
                    Button("Retry") { Task { await viewModel.load() } }
                        .font(.footnote.weight(.semibold))
                        .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}
