//
//  AdminReportWorkOrdersSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli ordini di lavoro: andamento dei completamenti e ripartizioni per stato, priorità, categoria e tipo,
//  in una griglia adattiva di schede.
//

import SwiftUI

struct AdminReportWorkOrdersSection: View {
    let viewModel: AdminReportsViewModel

    var body: some View {
        AdminReportSection(title: "Work orders", load: viewModel.workOrders,
                           emptyText: String(localized: "No work orders for this selection."),
                           isEmpty: \.isEmpty,
                           retry: { await viewModel.load() }) { report in
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], alignment: .leading, spacing: 12) {
                if !report.trend.isEmpty { AdminReportTrendChartCard(points: report.trend) }
                if !report.byStatus.isEmpty {
                    AdminReportBarChartCard(title: "By status", systemImage: "circle.dashed", items: report.byStatus)
                }
                if !report.byPriority.isEmpty {
                    AdminReportBarChartCard(title: "By priority", systemImage: "flag", items: report.byPriority)
                }
                if !report.byCategory.isEmpty {
                    AdminReportBarChartCard(title: "By category", systemImage: "square.grid.2x2",
                                            items: report.byCategory)
                }
                if !report.byType.isEmpty {
                    AdminReportBarChartCard(title: "By type", systemImage: "wrench.and.screwdriver",
                                            items: report.byType)
                }
            }
        }
    }
}
