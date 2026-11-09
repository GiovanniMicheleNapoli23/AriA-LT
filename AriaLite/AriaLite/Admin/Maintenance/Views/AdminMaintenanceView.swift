//
//  AdminMaintenanceView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Maintenance, come la pagina /maintenance della web: tile di riepilogo, filtri (stato,
//  stabilimento, asset, frequenza), ricerca, trascina per aggiornare, "+" per un piano nuovo.
//  Il dettaglio è in AdminMaintenanceDetailView.
//

import SwiftUI

struct AdminMaintenanceView: View {
    @Bindable var viewModel: AdminMaintenanceViewModel

    @State private var path: [AdminMaintenancePlan] = []
    @State private var isCreating = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AdminMaintenanceFilterBar(viewModel: viewModel)
                    if viewModel.hasLoaded {
                        AdminMaintenanceSummary(viewModel: viewModel)
                            .padding(.horizontal, 20)
                    }
                    errorPill
                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Maintenance")
            .navigationDestination(for: AdminMaintenancePlan.self) { plan in
                AdminMaintenanceDetailView(viewModel: viewModel.makeDetailViewModel(for: plan))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New plan", systemImage: "plus") { isCreating = true }
                        .disabled(!viewModel.canCreate)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Name, asset, category, zone"))
            .sheet(isPresented: $isCreating) {
                AdminMaintenanceFormView(viewModel: viewModel.makeFormViewModel()) { created in
                    viewModel.apply(created)
                    path.append(created)
                }
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // La lista non è mai arrivata: non si dice "nessun piano", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load plans", systemImage: "exclamationmark.triangle",
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
        } else if viewModel.visiblePlans.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No plans", systemImage: "calendar.badge.clock",
                                       description: Text("No maintenance plans match these filters."))
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
            ForEach(viewModel.visiblePlans) { plan in
                NavigationLink(value: plan) {
                    AdminMaintenancePlanRow(plan: plan)
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
