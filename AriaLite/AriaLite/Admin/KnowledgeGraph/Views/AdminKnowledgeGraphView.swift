//
//  AdminKnowledgeGraphView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Knowledge Graph, come la pagina /knowledge-graph della web ma pensata per il telefono:\n//  niente canvas da trascinare, un esploratore. Panoramica per tipo, ricerca globale, e dal dettaglio\n//  di ogni entità si passa a quelle collegate, a catena.
//

import SwiftUI

struct AdminKnowledgeGraphView: View {
    @Bindable var viewModel: AdminKnowledgeGraphViewModel

    @State private var path: [AdminKnowledgeGraphRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isSearching {
                        AdminKnowledgeGraphSearchResults(viewModel: viewModel)
                    } else {
                        content
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Knowledge Graph")
            .navigationDestination(for: AdminKnowledgeGraphRoute.self) { route in
                switch route {
                case .kind(let kind):
                    AdminKnowledgeGraphKindListView(viewModel: viewModel, kind: kind)
                case .entity(let ref):
                    AdminKnowledgeGraphEntityView(viewModel: viewModel, ref: ref)
                case .related(let ref, let kind):
                    AdminKnowledgeGraphRelatedListView(viewModel: viewModel, ref: ref, kind: kind)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Search assets, alarms, parts, documents…"))
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.blockingError {
            // Nessuna lista è arrivata: non si dice "grafo vuoto", si dice perché.
            VStack(spacing: 14) {
                ContentUnavailableView("Can't load the knowledge graph", systemImage: "exclamationmark.triangle",
                                       description: Text(message))
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .ariaGlassButtonStyle()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            AdminKnowledgeGraphOverview(viewModel: viewModel)
        }
    }
}
