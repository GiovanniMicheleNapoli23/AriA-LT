//
//  AdminMarketplaceView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Marketplace, come la pagina /marketplace della web: riepilogo, selettore di tipo, filtri e il
//  catalogo a scaffali in griglia adattiva. Il catalogo è locale e si vede sempre; i connettori veri arrivano
//  dal server e ne accendono lo stato. Dettagli: AdminConnectorDetailView e AdminMarketplaceItemDetailView.
//

import SwiftUI

struct AdminMarketplaceView: View {
    @Bindable var viewModel: AdminMarketplaceViewModel

    @State private var path: [AdminMarketplaceRoute] = []
    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 160
    @ScaledMetric(relativeTo: .body) private var statWidth: CGFloat = 130

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    errorPill
                    if !viewModel.isSearching { summary }
                    connectorsPending
                    kindPicker
                    activeFilters
                    content
                    updatedFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Marketplace")
            .navigationDestination(for: AdminMarketplaceRoute.self) { route in
                destination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
                if viewModel.canAddMaintainX {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("Add connector", systemImage: "plus") {
                            Button("MaintainX", systemImage: "wrench.and.screwdriver") { viewModel.openMaintainXForm() }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Search the marketplace"))
            .sheet(item: $viewModel.maintainXForm) { form in
                AdminConnectorCredentialsFormView(viewModel: form)
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    // MARK: Destinazioni

    @ViewBuilder
    private func destination(for route: AdminMarketplaceRoute) -> some View {
        switch route {
        case .connector(let provider):
            if let detail = viewModel.makeDetailViewModel(for: provider) {
                AdminConnectorDetailView(viewModel: detail)
            } else {
                ContentUnavailableView("Connector not found", systemImage: "puzzlepiece.extension",
                                       description: Text("Pull to refresh the list."))
            }
        case .item(let id):
            if let detail = viewModel.makeItemDetailViewModel(for: id) {
                AdminMarketplaceItemDetailView(viewModel: detail)
            } else {
                ContentUnavailableView("Item not found", systemImage: "square.grid.2x2",
                                       description: Text("It may have been removed from the catalog."))
            }
        }
    }

    // MARK: Riepilogo

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: statWidth), spacing: 10)], spacing: 10) {
            // I numeri dei connettori vengono dal server: finché non arrivano non si mostrano degli zeri.
            if viewModel.hasLoaded {
                AdminStatTile(title: String(localized: "Connected"), value: "\(viewModel.connectedCount)",
                              systemImage: "checkmark.circle.fill", tint: .green)
                AdminStatTile(title: String(localized: "Tools available"), value: "\(viewModel.toolCount)",
                              systemImage: "hammer.fill")
                if viewModel.attentionCount > 0 {
                    AdminStatTile(title: String(localized: "Need attention"), value: "\(viewModel.attentionCount)",
                                  systemImage: "exclamationmark.triangle.fill", tint: .orange)
                }
            }
            AdminStatTile(title: String(localized: "Owned"), value: "\(viewModel.ownedCount)",
                          systemImage: "checkmark.seal.fill")
        }
    }

    /// Lo stato dei connettori sta arrivando: una riga piccola, il catalogo sotto è già usabile.
    @ViewBuilder
    private var connectorsPending: some View {
        if !viewModel.hasLoaded, viewModel.errorMessage == nil {
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading connectors")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Tipi e filtri

    private var kindPicker: some View {
        AdminMarketplaceFlowLayout(spacing: 8) {
            ForEach(viewModel.kindChips) { chip in
                Button {
                    viewModel.select(kind: chip.kind)
                } label: {
                    AdminMarketplaceFilterChip(title: chip.title, count: chip.count, isSelected: chip.isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chip.isSelected ? .isSelected : [])
            }
        }
    }

    /// I filtri attivi come chip da togliere, più "Clear filters".
    @ViewBuilder
    private var activeFilters: some View {
        if viewModel.hasActiveFilters {
            AdminMarketplaceFlowLayout(spacing: 8) {
                ForEach(viewModel.activeFilters) { filter in
                    Button {
                        viewModel.remove(filter)
                    } label: {
                        AdminMarketplaceFilterChip(title: filter.title, isRemovable: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Removes this filter"))
                }
                Button("Clear filters") { viewModel.clearFilters() }
                    .font(.footnote.weight(.semibold))
                    .padding(.vertical, 8)
            }
        }
    }

    private var filterMenu: some View {
        Menu("Filters", systemImage: viewModel.hasActiveFilters
             ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") {
            Picker("Area", selection: $viewModel.area) {
                Text("All areas").tag(AdminMarketplaceArea?.none)
                ForEach(AdminMarketplaceArea.allCases) { area in
                    Text(area.label).tag(Optional(area))
                }
            }
            Picker("Ownership", selection: $viewModel.ownershipFilter) {
                ForEach(AdminMarketplaceOwnershipFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            if viewModel.showsMachineFacets {
                facetPicker("Machine", all: "All machines", selection: $viewModel.machineType,
                            options: viewModel.machineTypeOptions)
                facetPicker("Manufacturer", all: "All manufacturers", selection: $viewModel.manufacturer,
                            options: viewModel.manufacturerOptions)
                facetPicker("Industry", all: "All industries", selection: $viewModel.industry,
                            options: viewModel.industryOptions)
            }
            if viewModel.hasActiveFilters {
                Button("Clear filters", role: .destructive) { viewModel.clearFilters() }
            }
        }
    }

    @ViewBuilder
    private func facetPicker(_ title: LocalizedStringKey, all: LocalizedStringKey, selection: Binding<String?>,
                             options: [AdminMarketplaceFacetOption]) -> some View {
        if !options.isEmpty {
            Picker(title, selection: selection) {
                Text(all).tag(String?.none)
                ForEach(options) { option in
                    Text(option.label).tag(Optional(option.value))
                }
            }
        }
    }

    // MARK: Scaffali

    @ViewBuilder
    private var content: some View {
        let shelves = viewModel.shelves
        if !viewModel.isCatalogReady {
            // Il catalogo si legge alla prima apertura: non ancora pronto non è "vuoto".
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if shelves.isEmpty {
            emptyState
        } else {
            ForEach(shelves) { shelf in
                shelfView(shelf)
            }
        }
    }

    private func shelfView(_ shelf: AdminMarketplaceShelf) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shelf.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(shelf.blurb)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 12)], spacing: 12) {
                ForEach(shelf.items) { item in
                    NavigationLink(value: viewModel.route(for: item)) {
                        AdminMarketplaceItemCard(item: item, ownership: viewModel.ownership(of: item),
                                                 serverStatus: viewModel.serverStatus(for: item))
                    }
                    .buttonStyle(.plain)
                }
                ForEach(shelf.extraConnectors) { connector in
                    NavigationLink(value: AdminMarketplaceRoute.connector(connector.provider)) {
                        AdminConnectorTile(connector: connector)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.hasActiveFilters {
            VStack(spacing: 14) {
                ContentUnavailableView("No items match these filters", systemImage: "line.3.horizontal.decrease.circle",
                                       description: Text("Try removing a filter."))
                Button("Clear filters") { viewModel.clearFilters() }
                    .ariaGlassButtonStyle()
            }
            .padding(.top, 20)
        } else if viewModel.isSearching {
            ContentUnavailableView.search(text: viewModel.searchText)
        } else {
            ContentUnavailableView("Nothing here yet", systemImage: "square.grid.2x2",
                                   description: Text("The marketplace catalog is empty."))
                .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var updatedFooter: some View {
        if viewModel.hasLoaded, let updated = viewModel.lastUpdated {
            Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    /// L'ultimo caricamento dei connettori è fallito: una riga sottile con il motivo e "Retry". Il catalogo
    /// qui sotto resta visibile, è locale.
    @ViewBuilder
    private var errorPill: some View {
        if let message = viewModel.errorMessage {
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
