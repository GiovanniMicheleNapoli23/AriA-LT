//
//  AdminInspectionProgressCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'avanzamento dell'ispezione: barra, controlli fatti e da fare, e quelli da guardare (non spuntati con
//  una nota), evidenziati in arancione.
//

import SwiftUI

struct AdminInspectionProgressCard: View {
    let inspection: AdminInspection

    var body: some View {
        AdminCard(title: "Progress", systemImage: "chart.bar.fill") {
            AdminInspectionProgressBar(checked: inspection.checkedCount, total: inspection.totalCount)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                AdminStatTile(title: String(localized: "Done"), value: "\(inspection.checkedCount)",
                              systemImage: "checkmark.circle", tint: .green)
                AdminStatTile(title: String(localized: "To do"), value: "\(inspection.uncheckedCount)",
                              systemImage: "circle.dashed")
                AdminStatTile(title: String(localized: "Flagged"), value: "\(inspection.flaggedItems.count)",
                              systemImage: "exclamationmark.triangle",
                              tint: inspection.flaggedItems.isEmpty ? .secondary : .orange)
            }
            if !inspection.flaggedItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Needs attention")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .textCase(.uppercase)
                    ForEach(inspection.flaggedItems) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description).font(.subheadline.weight(.medium))
                            if let note = item.notes {
                                Text(note).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
