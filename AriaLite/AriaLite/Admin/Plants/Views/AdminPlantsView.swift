//
//  AdminPlantsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Plants, come la pagina /plants della web: elenco con ricerca, dettaglio, creazione.
//

import SwiftUI

struct AdminPlantsView: View {
    @Bindable var viewModel: AdminPlantsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    errorPill
                    content
                }
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .liteBackground()
            .navigationTitle("Plants")
            .navigationDestination(for: AdminPlant.self) { plant in
                AdminPlantDetailView(plant: plant, owner: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New plant", systemImage: "plus") { viewModel.startCreating() }
                }
            }
            .searchable(text: $viewModel.query, prompt: Text("Name, code, location..."))
            .sheet(item: $viewModel.newPlantForm) { form in
                AdminPlantFormView(viewModel: form)
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let placeholder = viewModel.placeholder {
            AdminPlantsPlaceholder(placeholder: placeholder) {
                Task { await viewModel.refresh() }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.visiblePlants) { plant in
                    NavigationLink(value: plant) {
                        AdminPlantRow(plant: plant, isActive: viewModel.isActive(plant))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)

            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
        }
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito: una riga sottile.
    @ViewBuilder
    private var errorPill: some View {
        if viewModel.refreshFailed {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
                Text("Couldn't refresh")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await viewModel.refresh() } }
                    .font(.footnote.weight(.semibold))
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .ariaGlass(in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
}
