//
//  AdminReportOverviewSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La panoramica: i sei numeri in una griglia adattiva (due colonne su un telefono, di più su iPad).
//

import SwiftUI

struct AdminReportOverviewSection: View {
    let viewModel: AdminReportsViewModel

    var body: some View {
        AdminReportSection(title: "Overview", load: viewModel.overview,
                           emptyText: String(localized: "No data for this selection."),
                           isEmpty: { _ in false },
                           retry: { await viewModel.load() }) { overview in
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(overview.tiles) { AdminReportKPITile(kpi: $0) }
            }
        }
    }
}
