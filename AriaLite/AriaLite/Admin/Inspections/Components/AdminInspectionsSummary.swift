//
//  AdminInspectionsSummary.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I riquadri in cima alla lista: quante ispezioni, aperte, scadute e completate (sulle visibili).
//  Una griglia adattiva: due colonne sul telefono, quattro in orizzontale o su iPad.
//

import SwiftUI

struct AdminInspectionsSummary: View {
    let summary: AdminInspectionCounts

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            AdminStatTile(title: String(localized: "Total"), value: "\(summary.total)", systemImage: "checklist")
            AdminStatTile(title: String(localized: "Open"), value: "\(summary.open)", systemImage: "play.circle", tint: .blue)
            AdminStatTile(title: String(localized: "Overdue"), value: "\(summary.overdue)",
                          systemImage: "exclamationmark.circle", tint: summary.overdue > 0 ? .red : .secondary)
            AdminStatTile(title: String(localized: "Completed"), value: "\(summary.completed)",
                          systemImage: "checkmark.seal", tint: .green)
        }
    }
}
