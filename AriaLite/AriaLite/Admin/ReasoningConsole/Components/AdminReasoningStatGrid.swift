//
//  AdminReasoningStatGrid.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I numeri in evidenza di una schermata, in una griglia che si adatta alla larghezza.
//

import SwiftUI

struct AdminReasoningStatGrid: View {
    let stats: [AdminReasoningStat]

    @ScaledMetric(relativeTo: .body) private var minWidth = 130

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: 10)], spacing: 10) {
            ForEach(stats) { stat in
                AdminStatTile(title: stat.title, value: stat.value, systemImage: stat.systemImage)
            }
        }
    }
}
