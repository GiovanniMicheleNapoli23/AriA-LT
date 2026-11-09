//
//  AdminReportAssetsSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli asset: ripartizioni per stato e tipo, e l'elenco di quelli che si guastano di più.
//

import SwiftUI

struct AdminReportAssetsSection: View {
    let viewModel: AdminReportsViewModel

    var body: some View {
        AdminReportSection(title: "Assets", load: viewModel.assets,
                           emptyText: String(localized: "No assets for this selection."),
                           isEmpty: \.isEmpty,
                           retry: { await viewModel.load() }) { report in
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], alignment: .leading, spacing: 12) {
                if !report.byStatus.isEmpty {
                    AdminReportBarChartCard(title: "By status", systemImage: "circle.dashed", items: report.byStatus)
                }
                if !report.byType.isEmpty {
                    AdminReportBarChartCard(title: "By type", systemImage: "gearshape.2", items: report.byType)
                }
                if !report.topFailing.isEmpty { topFailing(report.topFailing) }
            }
        }
    }

    private func topFailing(_ assets: [AdminReportFailingAsset]) -> some View {
        AdminCard(title: "Top failing assets", systemImage: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                    AdminReportFailingAssetRow(asset: asset, rank: index + 1)
                    if index < assets.count - 1 { Divider() }
                }
            }
        }
    }
}
