//
//  AdminAgentStudioRunSummaryRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Una riga dei run recenti: simbolo colorato dello stato, modalità, conteggio dei passi eseguiti,
//  quando è partito e il segno che si può aprire.
//

import SwiftUI

struct AdminAgentStudioRunSummaryRow: View {
    let symbol: String
    let tone: AdminAgentStudioTone
    let statusLabel: String?
    let modeLabel: String
    let counts: String?
    let relativeTime: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tone.color)
                .accessibilityLabel(statusLabel ?? "")
            VStack(alignment: .leading, spacing: 2) {
                Text(modeLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let counts {
                    Text(counts)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let relativeTime {
                    Text(relativeTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
