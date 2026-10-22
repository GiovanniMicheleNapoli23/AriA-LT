//
//  AdminAssetsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli asset dello stabilimento, come la pagina /assets della web: filtri (stato, tipo, zona), ricerca,
//  trascina per aggiornare, "+" per un asset nuovo. Il dettaglio è in AdminAssetDetailView.
//

import SwiftUI

struct AdminAssetsView: View {
    @Bindable var viewModel: AdminAssetsViewModel

    @State private var path: [AdminAsset] = []
    @State private var isCreating = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    filters
                    errorPill
                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Assets")
            .navigationDestination(for: AdminAsset.self) { asset in
                AdminAssetDetailView(viewModel: viewModel.makeDetailViewModel(for: asset))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New asset", systemImage: "plus") { isCreating = true }
                        .disabled(!viewModel.canCreate)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Tag, name, manufacturer, model"))
            .sheet(isPresented: $isCreating) {
                AdminAssetFormView(viewModel: viewModel.makeFormViewModel()) { created in
                    viewModel.apply(created)
                    path.append(created)
                }
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    // MARK: Filtri

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Status", selection: $viewModel.statusFilter) {
                        ForEach(AdminAssetStatus.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    AdminFilterChip(title: "Status", value: viewModel.statusFilter.label,
                                    isActive: viewModel.statusFilter != .approved)
                }
                Menu {
                    Picker("Type", selection: $viewModel.typeFilter) {
                        Text("All types").tag(AdminAssetType?.none)
                        ForEach(AdminAssetType.allCases) { Label($0.label, systemImage: $0.systemImage).tag(Optional($0)) }
                    }
                } label: {
                    AdminFilterChip(title: "Type", value: viewModel.typeFilterLabel, isActive: viewModel.typeFilter != nil)
                }
                if !viewModel.zones.isEmpty {
                    Menu {
                        Picker("Zone", selection: $viewModel.zoneFilter) {
                            Text("All zones").tag(String?.none)
                            ForEach(viewModel.zones, id: \.self) { Text($0).tag(Optional($0)) }
                        }
                    } label: {
                        AdminFilterChip(title: "Zone", value: viewModel.zoneFilterLabel, isActive: viewModel.zoneFilter != nil)
                    }
                }
                if viewModel.hasLocalFilters {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        withAnimation(.snappy) { viewModel.clearFilters() }
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Clear filters"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // La lista non è mai arrivata: non si dice "nessun asset", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load assets", systemImage: "exclamationmark.triangle",
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
        } else if viewModel.visibleAssets.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No assets", systemImage: "gearshape.2",
                                       description: Text("No assets match these filters in this plant."))
                    .padding(.top, 40)
            }
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
            ForEach(viewModel.visibleAssets) { asset in
                NavigationLink(value: asset) {
                    AdminAssetRow(asset: asset)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
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
            .padding(.horizontal, 20)
        }
    }
}
