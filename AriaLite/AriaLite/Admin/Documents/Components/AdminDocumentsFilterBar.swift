//
//  AdminDocumentsFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri della libreria: stato complessivo (sui documenti scaricati) e stabilimento (chiesto al server).
//

import SwiftUI

struct AdminDocumentsFilterBar: View {
    @Bindable var viewModel: AdminDocumentsViewModel

    var body: some View {
        // I filtri vanno a capo invece di scorrere di lato: la pagina scorre solo in verticale.
        AdminMobileUserFlowLayout(spacing: 8) {
            Menu {
                Picker("Status", selection: $viewModel.statusFilter) {
                    Text("All").tag(AdminDocumentStatusGroup?.none)
                    ForEach(AdminDocumentStatusGroup.allCases) {
                        Label($0.label, systemImage: $0.systemImage).tag(Optional($0))
                    }
                }
            } label: {
                AdminFilterChip(title: "Status", value: viewModel.statusFilterLabel, isActive: viewModel.statusFilter != nil)
            }
            if viewModel.plants.count > 1 {
                Menu {
                    Picker("Plant", selection: $viewModel.selectedPlantId) {
                        Text("All plants").tag(String?.none)
                        ForEach(viewModel.plants) { Text($0.name).tag(Optional($0.id)) }
                    }
                } label: {
                    AdminFilterChip(title: "Plant", value: viewModel.plantFilterLabel, isActive: viewModel.isPlantFilterCustom)
                }
            }
            if viewModel.statusFilter != nil {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    withAnimation(.snappy) { viewModel.clearFilters() }
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Clear filters"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
}
