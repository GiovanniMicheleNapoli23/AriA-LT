//
//  AdminAssetStatsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La disponibilità dell'asset negli ultimi 30 giorni, a riquadri (due per riga sul telefono,
//  di più dove c'è spazio).
//

import SwiftUI

struct AdminAssetStatsCard: View {
    let viewModel: AdminAssetDetailViewModel

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    var body: some View {
        AdminCard(title: "Last 30 days", systemImage: "chart.bar.xaxis") {
            if let items = viewModel.stats?.items, !items.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        AdminStatTile(title: item.title, value: item.value, systemImage: item.systemImage,
                                      tint: item.isWarning ? .orange : .liteAccent)
                    }
                }
            } else if let message = viewModel.statsError {
                AdminSectionNotice(text: message, isError: true)
            } else if viewModel.hasLoaded {
                AdminSectionNotice(text: String(localized: "No statistics for this asset yet."), systemImage: "chart.bar")
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }
}
