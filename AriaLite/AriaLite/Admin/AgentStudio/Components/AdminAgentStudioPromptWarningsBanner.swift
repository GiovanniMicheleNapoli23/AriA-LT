//
//  AdminAgentStudioPromptWarningsBanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Una riga sottile con il primo avviso del server e quanti sono; toccarla li apre tutti in un foglio.
//

import SwiftUI

struct AdminAgentStudioPromptWarningsBanner: View {
    let warnings: [String]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .accessibilityHidden(true)
                Text(warnings.first ?? "")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if warnings.count > 1 {
                    Text(verbatim: String(warnings.count))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18), in: Capsule())
                }
                Image(systemName: "chevron.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Shows all warnings"))
    }
}
