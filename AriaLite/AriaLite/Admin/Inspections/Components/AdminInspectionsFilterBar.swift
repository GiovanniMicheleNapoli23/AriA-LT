//
//  AdminInspectionsFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le chip di filtro della lista: stato, stabilimento, asset, area e scadenza. Stabilimento, asset e area
//  compaiono solo se ci sono almeno due scelte. Una fila che scorre in orizzontale va bene per le chip.
//

import SwiftUI

struct AdminInspectionsFilterBar: View {
    @Bindable var viewModel: AdminInspectionsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                status
                if viewModel.plants.count > 1 { plant }
                if viewModel.assetOptions.count > 1 { asset }
                if viewModel.zoneOptions.count > 1 { zone }
                due
                if viewModel.hasFilters {
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

    private var status: some View {
        Menu {
            Picker("Status", selection: $viewModel.statusFilter) {
                Text("All").tag(String?.none)
                ForEach(viewModel.statusOptions, id: \.self) { Text(AdminInspectionStatus.label(for: $0)).tag(Optional($0)) }
            }
        } label: {
            AdminFilterChip(title: "Status", value: viewModel.statusFilterLabel, isActive: viewModel.statusFilter != nil)
        }
    }

    private var plant: some View {
        Menu {
            Picker("Plant", selection: $viewModel.plantFilter) {
                Text("All plants").tag(String?.none)
                ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
            }
        } label: {
            AdminFilterChip(title: "Plant", value: viewModel.plantFilterLabel, isActive: viewModel.isPlantFilterCustom)
        }
    }

    private var asset: some View {
        Menu {
            Picker("Asset", selection: $viewModel.assetFilter) {
                Text("All assets").tag(String?.none)
                ForEach(viewModel.assetOptions, id: \.self) { Text($0).tag(Optional($0)) }
            }
        } label: {
            AdminFilterChip(title: "Asset", value: viewModel.assetFilterLabel, isActive: viewModel.assetFilter != nil)
        }
    }

    private var zone: some View {
        Menu {
            Picker("Area", selection: $viewModel.zoneFilter) {
                Text("All areas").tag(String?.none)
                ForEach(viewModel.zoneOptions, id: \.self) { Text($0).tag(Optional($0)) }
            }
        } label: {
            AdminFilterChip(title: "Area", value: viewModel.zoneFilterLabel, isActive: viewModel.zoneFilter != nil)
        }
    }

    private var due: some View {
        Menu {
            Picker("Date", selection: $viewModel.dueFilter) {
                ForEach(AdminInspectionDueFilter.allCases) { Text($0.label).tag($0) }
            }
        } label: {
            AdminFilterChip(title: "Date", value: viewModel.dueFilter.label, isActive: viewModel.dueFilter != .any)
        }
    }
}
