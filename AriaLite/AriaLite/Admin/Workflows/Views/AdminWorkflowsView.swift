//
//  AdminWorkflowsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Workflows, come la pagina /workflows della web: l'elenco dei flussi con filtro di stato e
//  ricerca, "+" per crearne uno (vuoto o da un modello). Dettaglio in AdminWorkflowDetailView.
//

import SwiftUI

struct AdminWorkflowsView: View {
    @Bindable var viewModel: AdminWorkflowsViewModel

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AdminWorkflowFilters(viewModel: viewModel)
                    errorPill
                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Workflows")
            .navigationDestination(for: String.self) { flowId in
                AdminWorkflowDetailView(viewModel: viewModel.makeDetailViewModel(flowId: flowId))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New flow", systemImage: "plus") { viewModel.startCreating() }
                        .disabled(!viewModel.canCreate)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Name or description"))
            .sheet(item: $viewModel.newFlowForm) { form in
                AdminWorkflowFormView(viewModel: form) { viewModel.didCreate($0) }
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // La lista non è mai arrivata: non si dice "nessun flusso", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load the workflows", systemImage: "exclamationmark.triangle",
                                           description: Text(message))
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .ariaGlassButtonStyle()
                }
                .padding(.top, 40)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        } else if viewModel.visibleFlows.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No flows", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                                       description: Text("Create a flow to decide how Aria's agents work together."))
                    .padding(.top, 40)
            }
            loadMoreButton
        } else {
            list
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            ForEach(viewModel.visibleFlows) { flow in
                NavigationLink(value: flow.id) { AdminWorkflowRow(flow: flow) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
            }
            loadMoreButton
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
    }

    /// Le pagine dopo la prima: la ricerca cerca solo fra i flussi scaricati.
    @ViewBuilder
    private var loadMoreButton: some View {
        if viewModel.canLoadMore {
            Button {
                Task { await viewModel.loadMore() }
            } label: {
                if viewModel.isLoadingMore {
                    ProgressView()
                } else {
                    Label("Load more", systemImage: "arrow.down.circle")
                }
            }
            .ariaGlassButtonStyle()
            .disabled(viewModel.isLoadingMore)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile con il motivo.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.hasLoaded, let message = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button("Retry") { Task { await viewModel.load() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
    }
}
