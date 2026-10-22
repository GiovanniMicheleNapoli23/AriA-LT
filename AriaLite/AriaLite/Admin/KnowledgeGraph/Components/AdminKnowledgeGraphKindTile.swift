//
//  AdminKnowledgeGraphKindTile.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una casella della panoramica: icona, numero e nome del tipo; se la lista non è arrivata,\n//  il motivo al posto del numero (la casella allora non si apre).
//

import SwiftUI

struct AdminKnowledgeGraphKindTile: View {
    let tile: AdminKnowledgeGraphTile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                AdminKnowledgeGraphKindIcon(kind: tile.kind, size: 32)
                Spacer(minLength: 4)
                if tile.isAvailable {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            value
            Text(tile.kind.pluralTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var value: some View {
        switch tile.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .leading)
        case .count(let count):
            Text(count, format: .number)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
        case .unavailable(let reason):
            Label(reason, systemImage: "lock")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}
