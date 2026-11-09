//
//  AdminMemoryFactRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di un fatto nella lista: stato, testo (nella lingua del telefono se tradotto), contesto
//  e chi l'ha proposto, dove e quando. Tutto arriva già pronto dal view model.
//

import SwiftUI

struct AdminMemoryFactRow: View {
    let fact: AdminMemoryFact
    let text: String
    let isTranslated: Bool
    let metaLine: String
    var isBusy = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let status = fact.status { AdminMemoryFactStatusBadge(status: status) }
                if let category = fact.category {
                    Text(category)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if isBusy {
                    ProgressView().controlSize(.small)
                } else if isTranslated {
                    Image(systemName: "translate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Translated"))
                }
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 8 : 4)
            if let context = fact.context {
                Text(context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .opacity(isBusy ? 0.6 : 1)
    }
}
