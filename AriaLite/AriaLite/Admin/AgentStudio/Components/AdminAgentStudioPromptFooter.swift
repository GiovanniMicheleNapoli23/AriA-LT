//
//  AdminAgentStudioPromptFooter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  La barra sotto l'editor del prompt: numero di caratteri, ora dell'ultimo salvataggio e "Discard"
//  se il testo è cambiato.
//

import SwiftUI

struct AdminAgentStudioPromptFooter: View {
    let characterCount: String
    let savedLabel: String?
    let hasChanges: Bool
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(characterCount)
            if let savedLabel {
                Text(verbatim: "·").accessibilityHidden(true)
                Text(savedLabel)
            }
            Spacer(minLength: 8)
            if hasChanges {
                Button("Discard", action: onDiscard)
                    .font(.caption.weight(.semibold))
                    .tint(Color.liteAccent)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}
