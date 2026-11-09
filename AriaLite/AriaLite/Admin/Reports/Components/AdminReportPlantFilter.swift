//
//  AdminReportPlantFilter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il filtro per stabilimento in cima alla pagina: un menu con "All plants" e gli stabilimenti
//  dell'azienda, e l'ora dell'ultimo aggiornamento.
//

import SwiftUI

struct AdminReportPlantFilter: View {
    @Bindable var viewModel: AdminReportsViewModel

    var body: some View {
        HStack(spacing: 12) {
            if !viewModel.plants.isEmpty {
                Menu {
                    Picker("Plant", selection: $viewModel.plantFilterId) {
                        Text("All plants").tag(String?.none)
                        ForEach(viewModel.plants) { plant in
                            Text(plant.name).tag(String?.some(plant.id))
                        }
                    }
                } label: {
                    Label(viewModel.plantFilterLabel, systemImage: "building.2")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .ariaGlass(in: Capsule())
                }
                .accessibilityLabel("Plant")
                .accessibilityValue(viewModel.plantFilterLabel)
            }
            Spacer(minLength: 0)
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
