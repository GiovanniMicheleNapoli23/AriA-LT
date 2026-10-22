//
//  AdminMarketplaceView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Marketplace, come la pagina /marketplace della web: riepilogo, connettori in griglia
//  adattiva divisi per stato, ricerca e trascina per aggiornare. Il dettaglio è in AdminConnectorDetailView.
//

import SwiftUI

struct AdminMarketplaceView: View {
    @Bindable var viewModel: AdminMarketplaceViewModel

    @State private var path: [String] = []
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 160
    @ScaledMetric(relativeTo: .body) private var statWidth: CGFloat = 130

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    errorPill
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Marketplace")
            .navigationDestination(for: String.self) { provider in
                if let detail = viewModel.makeDetailViewModel(for: provider) {
                    AdminConnectorDetailView(viewModel: detail)
                } else {
                    ContentUnavailableView("Connector not found", systemImage: "puzzlepiece.extension",
                                           description: Text("Pull to refresh the list."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                if viewModel.canAddMaintainX {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("Add connector", systemImage: "plus") {
                            Button("MaintainX", systemImage: "wrench.and.screwdriver") { viewModel.openMaintainXForm() }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Search connectors"))
            .sheet(item: $viewModel.maintainXForm) { form in
                AdminConnectorCredentialsFormView(viewModel: form)
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // La lista non è mai arrivata: non si dice "nessun connettore", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load connectors", systemImage: "exclamationmark.triangle",
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
        } else if viewModel.sections.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No connectors", systemImage: "puzzlepiece.extension",
                                       description: Text("Connect a system so Aria can read and act on its data."))
                    .padding(.top, 40)
            }
        } else {
            if !viewModel.isSearching { summary }
            ForEach(viewModel.sections) { section in
                sectionView(section)
            }
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: statWidth), spacing: 10)], spacing: 10) {
            AdminStatTile(title: String(localized: "Connected"), value: "\(viewModel.connectedCount)",
                          systemImage: "checkmark.circle.fill", tint: .green)
            AdminStatTile(title: String(localized: "Tools available"), value: "\(viewModel.toolCount)",
                          systemImage: "hammer.fill")
            if viewModel.attentionCount > 0 {
                AdminStatTile(title: String(localized: "Need attention"), value: "\(viewModel.attentionCount)",
                              systemImage: "exclamationmark.triangle.fill", tint: .orange)
            }
        }
    }

    private func sectionView(_ section: AdminMarketplaceSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.kind.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 12)], spacing: 12) {
                ForEach(section.connectors) { connector in
                    NavigationLink(value: connector.provider) {
                        AdminConnectorTile(connector: connector)
                    }
                    .buttonStyle(.plain)
                }
            }
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
        }
    }
}
