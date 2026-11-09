//
//  AdminAgentStudioPromptHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  L'intestazione compatta dell'editor del prompt: pastiglia Custom/Default e una riga di descrizione
//  (nascosta con poca altezza, come l'iPhone in orizzontale con la tastiera, per lasciarla al testo).
//

import SwiftUI

struct AdminAgentStudioPromptHeader: View {
    let prompt: AdminAgentStudioAgentPrompt

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if prompt.isOverridden {
                AdminAgentStudioBadge(text: String(localized: "Custom"), tone: .active)
            } else {
                AdminAgentStudioBadge(text: String(localized: "Default"), tone: .neutral)
            }
            if verticalSizeClass != .compact, let description = prompt.description {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
