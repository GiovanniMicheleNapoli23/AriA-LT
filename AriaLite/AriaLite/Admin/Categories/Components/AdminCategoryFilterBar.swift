//
//  AdminCategoryFilterBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri della lista: tipo e stabilimento, due menu compatti (niente scorrimento orizzontale).
//

import SwiftUI

struct AdminCategoryFilterBar: View {
    let viewModel: AdminCategoriesViewModel

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Entity type", selection: entityBinding) {
                    Text("All types").tag(String?.none)
                    ForEach(viewModel.entityTypes, id: \.self) { type in
                        Text(type).tag(Optional(type))
                    }
                }
            } label: {
                filterLabel(title: viewModel.entityFilter ?? String(localized: "All types"),
                            systemImage: "square.grid.2x2")
            }
            .disabled(viewModel.entityTypes.isEmpty)

            if !viewModel.plants.isEmpty {
                Menu {
                    Picker("Plant", selection: plantBinding) {
                        Text("All plants").tag(String?.none)
                        ForEach(viewModel.plants) { plant in
                            Text(plant.name).tag(Optional(plant.id))
                        }
                    }
                } label: {
                    filterLabel(title: viewModel.plantFilter.flatMap { id in
                        viewModel.plants.first { $0.id == id }?.name
                    } ?? String(localized: "All plants"), systemImage: "building.2")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private var entityBinding: Binding<String?> {
        Binding(get: { viewModel.entityFilter }, set: { viewModel.entityFilter = $0 })
    }

    private var plantBinding: Binding<String?> {
        Binding(get: { viewModel.plantFilter }, set: { viewModel.plantFilter = $0 })
    }

    private func filterLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.background.secondary, in: .capsule)
    }
}
