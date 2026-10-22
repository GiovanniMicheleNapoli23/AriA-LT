//
//  AdminKnowledgeGraphRunRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un'elaborazione di un documento: stato, quando, pezzi indicizzati ed entità estratte; l'errore\n//  sotto, se c'è.
//

import SwiftUI

struct AdminKnowledgeGraphRunRow: View {
    let run: AdminKnowledgeGraphDocumentRun
    let title: String
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                if let date = run.date {
                    Text(date, format: .dateTime.day().month().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let summary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let error = run.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
