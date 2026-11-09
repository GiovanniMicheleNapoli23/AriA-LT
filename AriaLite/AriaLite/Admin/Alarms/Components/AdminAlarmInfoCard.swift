//
//  AdminAlarmInfoCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda "Details": asset, categoria, zona, pagina HMI, fiducia dell'estrazione e date. A testo grande
//  l'etichetta va sopra il valore.
//

import SwiftUI

struct AdminAlarmInfoCard: View {
    let rows: [(label: String, value: String)]

    var body: some View {
        AdminCard(title: "Details", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.label).font(.caption).foregroundStyle(.secondary)
                        Text(verbatim: row.value).font(.subheadline).textSelection(.enabled)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
