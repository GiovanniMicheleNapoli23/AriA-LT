//
//  AdminInspectionsView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le ispezioni, come la pagina /inspections della web: riepilogo a riquadri, ricerca, filtri (stato,
//  stabilimento, asset, area, data), trascina per aggiornare, "+" per una nuova. Il dettaglio è in
//  AdminInspectionDetailView.
//

import SwiftUI

struct AdminInspectionsView: View {
    @Bindable var viewModel: AdminInspectionsViewModel

    @State private var path: [AdminInspection] = []
    @State private var isCreating = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.hasLoaded { summary }
                    AdminInspectionsFilterBar(viewModel: viewModel)
                    errorPill
                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Inspections")
            .navigationDestination(for: AdminInspection.self) { inspection in
                AdminInspectionDetailView(viewModel: viewModel.makeDetailViewModel(for: inspection))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New inspection", systemImage: "plus") { isCreating = true }
                        .disabled(!viewModel.canCreate)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Title, asset, area, assignee"))
            .sheet(isPresented: $isCreating) {
                AdminInspectionFormView(viewModel: viewModel.makeFormViewModel()) { created in
                    viewModel.apply(created)
                    path.append(created)
                }
            }
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    // MARK: Contenuto

    private var summary: some View {
        AdminInspectionsSummary(summary: viewModel.summary)
            .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // La lista non è mai arrivata: non si dice "nessuna ispezione", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load inspections", systemImage: "exclamationmark.triangle",
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
        } else if viewModel.visibleInspections.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView {
                    Label("No inspections", systemImage: "checklist")
                } description: {
                    if viewModel.hasFilters {
                        Text("No inspection matches these filters.")
                    } else {
                        Text("Create the first inspection with the + button.")
                    }
                }
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 8, alignment: .top)], spacing: 8) {
                ForEach(viewModel.visibleInspections) { inspection in
                    NavigationLink(value: inspection) {
                        AdminInspectionRow(inspection: inspection, plantName: plantName(for: inspection))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            if let updated = viewModel.lastUpdated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
    }

    /// Il nome dello stabilimento solo se ce n'è più d'uno: con uno solo è rumore.
    private func plantName(for inspection: AdminInspection) -> String? {
        guard viewModel.plants.count > 1, let id = inspection.plantId else { return nil }
        return viewModel.plantName(id)
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
