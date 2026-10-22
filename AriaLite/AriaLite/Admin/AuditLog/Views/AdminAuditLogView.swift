//
//  AdminAuditLogView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo storico delle modifiche, come la pagina /audit-log della web: righe raggruppate per giorno, filtri
//  (tipo, azione), ricerca, "Carica altro" in fondo. Il dettaglio di una riga è in AdminAuditLogDetailView.
//

import SwiftUI

struct AdminAuditLogView: View {
    @Bindable var viewModel: AdminAuditLogViewModel

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .ariaReadableWidth()
            }
            .refreshable { await viewModel.load() }
            .liteBackground()
            .navigationTitle("Audit log")
            .navigationDestination(for: String.self) { id in
                if let detail = viewModel.detail(id: id) {
                    AdminAuditLogDetailView(detail: detail)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { AriaSidebarButton() }
                ToolbarItem(placement: .topBarTrailing) { AdminAuditLogFilterMenu(viewModel: viewModel) }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("Person, item, field"))
        }
        .task(id: viewModel.loadKey) { await viewModel.load() }
    }

    // MARK: Contenuto

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if let message = viewModel.errorMessage {
                // La lista non è mai arrivata: non si dice "nessuna modifica", si dice perché.
                VStack(spacing: 14) {
                    ContentUnavailableView("Can't load the audit log", systemImage: "exclamationmark.triangle",
                                           description: Text(message))
                    retryButton
                }
                .padding(.top, 40)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }
        } else if viewModel.visibleEntries.isEmpty {
            if viewModel.isSearching {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                ContentUnavailableView("No activity", systemImage: "list.bullet.rectangle",
                                       description: Text(viewModel.hasFilters
                                           ? "No changes match these filters."
                                           : "Changes made in the company will appear here."))
                    .padding(.top, 40)
            }
            footer
        } else {
            ForEach(viewModel.sections) { section in
                daySection(section)
            }
            footer
        }
    }

    private func daySection(_ section: AdminAuditLogDaySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
            VStack(spacing: 0) {
                ForEach(section.rows) { row in
                    NavigationLink(value: row.id) {
                        AdminAuditLogRowView(row: row)
                    }
                    .buttonStyle(.plain)
                    if row.id != section.rows.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// Errore di una pagina successiva (le righe restano) e "Carica altro".
    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                retryButton
            }
            if viewModel.canLoadMore {
                Button {
                    Task { await viewModel.loadMore() }
                } label: {
                    if viewModel.isLoadingMore {
                        ProgressView()
                    } else {
                        Label("Load more", systemImage: "arrow.down.circle")
                    }
                }
                .disabled(viewModel.isLoadingMore)
                .ariaGlassButtonStyle()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var retryButton: some View {
        Button {
            Task { await viewModel.load() }
        } label: {
            Label("Retry", systemImage: "arrow.clockwise")
        }
        .ariaGlassButtonStyle()
    }
}
