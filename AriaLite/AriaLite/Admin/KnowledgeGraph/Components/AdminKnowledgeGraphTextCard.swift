//
//  AdminKnowledgeGraphTextCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un testo lungo del dettaglio: un paragrafo, o un elenco numerato quando le righe sono più d'una\n//  (cause tipiche, passi di risoluzione, attività del piano).
//

import SwiftUI

struct AdminKnowledgeGraphTextCard: View {
    let block: AdminKnowledgeGraphTextBlock

    var body: some View {
        AdminCard(title: LocalizedStringKey(block.title), systemImage: block.systemImage) {
            if block.lines.count == 1, let line = block.lines.first {
                Text(line)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(block.lines.enumerated()), id: \.offset) { position, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(verbatim: "\(position + 1).")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(line)
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
