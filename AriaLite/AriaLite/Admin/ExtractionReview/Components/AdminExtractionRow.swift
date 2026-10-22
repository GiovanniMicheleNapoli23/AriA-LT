//
//  AdminExtractionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un elemento da rivedere: codice, titolo, riepilogo, stato e confidenza dell'AI.
//  In selezione multipla mostra il cerchio di scelta a sinistra.
//

import SwiftUI

struct AdminExtractionRow: View {
    let item: AdminExtractionItem
    var isSelecting = false
    var isSelected = false
    var isBusy = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var iconSize = 36

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.liteAccent : Color.secondary)
                    .opacity(item.canEdit ? 1 : 0.3)
                    .accessibilityHidden(true)
            } else if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: item.kind.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color.liteAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                if let code = item.code {
                    Text(code)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(Color.liteAccent)
                }
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                }
            }
            Spacer(minLength: 8)
            if isBusy {
                ProgressView()
            } else {
                VStack(alignment: .trailing, spacing: 6) {
                    if let status = item.status { AdminAssetStatusBadge(status: status) }
                    if let confidence = item.confidence { AdminExtractionConfidenceBadge(confidence: confidence) }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16),
                   tint: isSelecting && isSelected ? Color.liteAccent.opacity(0.10) : nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelecting && isSelected ? .isSelected : [])
    }
}
