//
//  AdminReasoningSessionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di una sessione nella lista della console: titolo, ultima attività e id abbreviato.
//

import SwiftUI

struct AdminReasoningSessionRow: View {
    let session: AriaSessionSummary

    @ScaledMetric(relativeTo: .subheadline) private var iconSize = 34

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(width: iconSize, height: iconSize)
                .background(Color.liteAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(AdminReasoningFormat.trimmed(session.title) ?? String(localized: "Untitled session"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let last = session.lastActivity {
                        Text(last, format: .relative(presentation: .named))
                    }
                    Text(session.sessionId.prefix(8))
                        .monospaced()
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}
