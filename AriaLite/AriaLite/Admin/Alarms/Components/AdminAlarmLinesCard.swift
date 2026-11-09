//
//  AdminAlarmLinesCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sezione del dettaglio con un elenco: le cause tipiche (puntato) o i passi di risoluzione (numerato).
//  Vuota, dice che non c'è niente.
//

import SwiftUI

struct AdminAlarmLinesCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let lines: [String]
    var isNumbered = false

    var body: some View {
        AdminCard(title: title, systemImage: systemImage) {
            if lines.isEmpty {
                Text("Nothing recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(verbatim: isNumbered ? "\(index + 1)." : "•")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .accessibilityHidden(true)
                            Text(verbatim: line)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }
}
