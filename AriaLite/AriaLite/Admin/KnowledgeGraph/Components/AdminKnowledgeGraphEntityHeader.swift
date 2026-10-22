//
//  AdminKnowledgeGraphEntityHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'intestazione del dettaglio di un'entità: tipo, titolo, righe sotto, stato e quanti collegamenti ha.
//

import SwiftUI

struct AdminKnowledgeGraphEntityHeader: View {
    let node: AdminKnowledgeGraphNode
    let linkSummary: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AdminKnowledgeGraphKindIcon(kind: node.kind, size: 52)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(node.kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(node.kind.tint)
                        .textCase(.uppercase)
                    if let status = node.status { AdminKnowledgeGraphStatusBadge(text: status) }
                }
                Text(node.title)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Label(linkSummary, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
