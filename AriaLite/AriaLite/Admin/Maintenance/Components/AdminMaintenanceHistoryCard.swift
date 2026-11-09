//
//  AdminMaintenanceHistoryCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo storico delle modifiche del piano (GET /v1/audit-log): linea del tempo, dal più recente, a pagine.
//  Le righe sono quelle dello storico degli ordini di lavoro (AdminWorkOrderAuditRow).
//

import SwiftUI

struct AdminMaintenanceHistoryCard: View {
    let viewModel: AdminMaintenanceHistoryViewModel

    var body: some View {
        AdminCard(title: "History", systemImage: "clock.arrow.circlepath") {
            AdminWorkOrderActivityRefreshButton(isLoading: viewModel.isLoading) {
                Task { await viewModel.load() }
            }
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                if let message = viewModel.errorMessage { AdminWorkOrderActivityError(message: message) }
                timeline
            }
        }
        .task { if !viewModel.hasLoaded { await viewModel.load() } }
    }

    private var timeline: some View {
        let rows = viewModel.rows
        return VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                if viewModel.hasLoaded {
                    AdminSectionNotice(text: String(localized: "No changes recorded yet."), systemImage: "clock")
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                AdminWorkOrderAuditRow(row: row, isLast: index == rows.count - 1 && !viewModel.hasMore)
            }
            if viewModel.hasMore {
                Button {
                    Task { await viewModel.loadMore() }
                } label: {
                    if viewModel.isLoadingMore { ProgressView() } else { Text("Load more") }
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .disabled(viewModel.isLoadingMore)
            }
        }
    }
}
