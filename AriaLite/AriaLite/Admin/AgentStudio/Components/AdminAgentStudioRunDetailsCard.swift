//
//  AdminAgentStudioRunDetailsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  I dati del run (campi e contatori) in una scheda che resta chiusa mentre il run gira e si apre a run finito.
//

import SwiftUI

struct AdminAgentStudioRunDetailsCard: View {
    let fields: [AdminAssetField]
    let counters: [(title: String, value: Int, status: String)]
    let isActive: Bool

    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 120

    var body: some View {
        AdminAgentStudioDisclosureCard(title: "Details", systemImage: "info.circle", startsExpanded: !isActive) {
            VStack(alignment: .leading, spacing: 12) {
                if !counters.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 10)], spacing: 10) {
                        ForEach(counters, id: \.status) { counter in
                            AdminStatTile(title: counter.title, value: "\(counter.value)",
                                          tint: AdminAgentStudioStatus.tone(for: counter.status).color)
                        }
                    }
                }
                VStack(spacing: 0) {
                    ForEach(fields) { field in
                        AdminFieldRow(field: field, showsDivider: field != fields.last)
                    }
                }
            }
        }
    }
}
