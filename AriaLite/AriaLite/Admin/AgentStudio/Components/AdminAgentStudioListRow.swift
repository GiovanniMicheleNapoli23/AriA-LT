//
//  AdminAgentStudioListRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di una riga nelle liste di Agent Studio (workflow, run, approvazioni): icona, titolo,
//  una o due righe secondarie e una pastiglia di stato a destra. Con il testo enorme l'icona sparisce.
//

import SwiftUI

struct AdminAgentStudioListRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    var footnote: String?
    var badge: AdminAgentStudioBadge?
    var iconTint: Color = .liteAccent

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                AdminAgentStudioIcon(systemImage: systemImage, tint: iconTint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                }
                if let footnote {
                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let badge { badge }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
