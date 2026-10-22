//
//  AdminMaintenanceFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri della lista: stato (chiesto al server), stabilimento, asset e frequenza (sui piani scaricati).
//

import SwiftUI

struct AdminMaintenanceFilterBar: View {
    @Bindable var viewModel: AdminMaintenanceViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Status", selection: $viewModel.statusFilter) {
                        ForEach(AdminMaintenanceStatus.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    AdminFilterChip(title: "Status", value: viewModel.statusFilter.label,
                                    isActive: viewModel.statusFilter != .approved)
                }
                if viewModel.plants.count > 1 {
                    Menu {
                        Picker("Plant", selection: $viewModel.plantFilter) {
                            Text("All plants").tag(String?.none)
                            ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                        }
                    } label: {
                        AdminFilterChip(title: "Plant", value: viewModel.plantFilterLabel,
                                        isActive: viewModel.isPlantFilterCustom)
                    }
                }
                if !viewModel.assetTags.isEmpty {
                    Menu {
                        Picker("Asset", selection: $viewModel.assetFilter) {
                            Text("All assets").tag(String?.none)
                            ForEach(viewModel.assetTags, id: \.self) { Text($0).tag(Optional($0)) }
                        }
                    } label: {
                        AdminFilterChip(title: "Asset", value: viewModel.assetFilterLabel, isActive: viewModel.assetFilter != nil)
                    }
                }
                Menu {
                    Picker("Frequency", selection: $viewModel.frequencyFilter) {
                        Text("All").tag(AdminMaintenanceFrequency?.none)
                        ForEach(AdminMaintenanceFrequency.allCases) {
                            Label($0.label, systemImage: $0.systemImage).tag(Optional($0))
                        }
                    }
                } label: {
                    AdminFilterChip(title: "Frequency", value: viewModel.frequencyFilterLabel,
                                    isActive: viewModel.frequencyFilter != nil)
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
}
