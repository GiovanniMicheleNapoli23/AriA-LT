//
//  AdminCraftedArtifactMessageRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un messaggio della conversazione di un artifact: una risposta data dopo in chat a destra, e Aria a
//  sinistra con il testo formattato come in chat e le sue card (prima i deliverable, poi il contesto).
//

import SwiftUI

struct AdminCraftedArtifactMessageRow: View {
    let message: AriaAgentMessage
    let actions: AriaArtifactActions

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.displayText)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.liteAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        case .assistant:
            VStack(alignment: .leading, spacing: 12) {
                let text = message.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    AriaMarkdownView(text: text).textSelection(.enabled)
                }
                ForEach(message.artifacts.filter(\.isDeliverable)) { AriaArtifactView(artifact: $0, actions: actions) }
                ForEach(message.artifacts.filter { !$0.isDeliverable }) { AriaArtifactView(artifact: $0, actions: actions) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
