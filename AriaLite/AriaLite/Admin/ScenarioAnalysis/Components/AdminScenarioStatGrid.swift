//
//  AdminScenarioStatGrid.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le tessere riassuntive in una griglia che si adatta alla larghezza (2 colonne su iPhone, di più su iPad).
//

import SwiftUI

struct AdminScenarioStatGrid: View {
    let stats: [AdminScenarioStat]

    @ScaledMetric(relativeTo: .body) private var minimumWidth: CGFloat = 140

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 10)], spacing: 10) {
            ForEach(stats) { stat in
                AdminStatTile(title: stat.title, value: stat.value, systemImage: stat.systemImage, tint: stat.tone.color)
            }
        }
    }
}
