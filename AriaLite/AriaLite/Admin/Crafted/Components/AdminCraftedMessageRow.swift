//
//  AdminCraftedMessageRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un messaggio della conversazione in sola lettura: l'operatore a destra, Aria a sinistra con il testo
//  formattato e le sue card. Sotto ogni card che viene da un tool c'è "Pin to Crafted".
//

import SwiftUI

struct AdminCraftedMessageRow: View {
    let message: AriaAgentMessage
    let viewModel: AdminCraftedSessionViewModel

    @Environment(\.openURL) private var openURL

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
            VStack(alignment: .leading, spacing: 10) {
                let text = message.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    AriaMarkdownView(text: text)
                        .textSelection(.enabled)
                }
                ForEach(viewModel.artifacts(of: message)) { artifact in
                    VStack(alignment: .trailing, spacing: 6) {
                        AriaArtifactView(artifact: artifact, actions: AriaArtifactActions(open: { path in
                            if let url = viewModel.webURL(for: path) { openURL(url) }
                        }))
                        pinButton(artifact)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func pinButton(_ artifact: AriaArtifact) -> some View {
        if viewModel.isPinned(artifact) {
            Label("Pinned to Crafted", systemImage: "pin.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
        } else if artifact.source != nil {
            Button {
                Task { await viewModel.pin(artifact) }
            } label: {
                if viewModel.pinningId == artifact.id {
                    ProgressView()
                } else {
                    Label("Pin to Crafted", systemImage: "pin")
                }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderless)
            .disabled(!viewModel.canPin(artifact))
        }
    }
}
