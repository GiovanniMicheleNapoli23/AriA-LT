//
//  AdminReasoningSentenceRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una frase della risposta con la fonte del prompt a cui somiglia di più e il punteggio.
//  Le frasi senza fonte sopra la soglia (`unsupported`) sono in arancio.
//

import SwiftUI

struct AdminReasoningSentenceRow: View {
    let sentence: AdminReasoningSentence
    let source: String?
    let score: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(sentence.isUnsupported ? Color.orange : Color.liteAccent)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(sentence.text)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if sentence.isUnsupported {
                        Label("Unsupported", systemImage: "questionmark.circle")
                            .foregroundStyle(.orange)
                    } else if let source {
                        Label(source, systemImage: "link")
                            .lineLimit(2)
                    }
                    if let score {
                        Text(score).monospacedDigit().foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
    }
}
