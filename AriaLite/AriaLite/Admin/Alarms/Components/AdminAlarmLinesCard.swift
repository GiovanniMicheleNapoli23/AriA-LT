//
//  AdminAlarmLinesCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sezione del dettaglio con un elenco: le cause tipiche (puntato) o i passi di risoluzione (numerato),
//  con quante sono accanto al titolo. Vuota, lo dice e offre di completarla con l'AI.
//

import SwiftUI

struct AdminAlarmLinesCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let lines: [String]
    var isNumbered = false
    /// Apre "Improve with AI" quando la sezione è vuota.
    var fillIn: (() -> Void)?

    var body: some View {
        AdminCard(title: title, systemImage: systemImage) {
            if !lines.isEmpty {
                Text(lines.count, format: .number)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                    .accessibilityHidden(true)
            }
        } content: {
            if lines.isEmpty {
                empty
            } else {
                AdminAlarmNumberedList(lines: lines, isNumbered: isNumbered)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing recorded yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let fillIn {
                Button(action: fillIn) {
                    Label("Fill in with AI", systemImage: "sparkles")
                }
                .font(.subheadline.weight(.semibold))
                .ariaGlassButtonStyle()
            }
        }
    }
}
