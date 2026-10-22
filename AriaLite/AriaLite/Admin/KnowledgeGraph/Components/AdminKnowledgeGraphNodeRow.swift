//
//  AdminKnowledgeGraphNodeRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La riga di un nodo in tutte le liste (tipo, ricerca, relazioni): icona del tipo, titolo,\n//  una o due righe sotto e lo stato a destra.
//

import SwiftUI

struct AdminKnowledgeGraphNodeRow: View {
    let node: AdminKnowledgeGraphNode
    /// Numero di collegamenti da mostrare a destra (nodi centrali), al posto dello stato.
    var links: Int?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Testo enorme: l'icona ruberebbe spazio al titolo.
            if !dynamicTypeSize.isAccessibilitySize {
                AdminKnowledgeGraphKindIcon(kind: node.kind)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(node.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                if let detail = node.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                }
            }
            Spacer(minLength: 8)
            if let links {
                Label {
                    Text(links, format: .number)
                } icon: {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                }
                .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("\(links) links"))
            } else if let status = node.status {
                AdminKnowledgeGraphStatusBadge(text: status)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
