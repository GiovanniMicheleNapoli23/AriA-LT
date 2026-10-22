//
//  AriaMessageToolbar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Sotto una risposta finita: copia, leggi ad alta voce, voto, rigenera e i chip di follow-up.
//

import SwiftUI

struct AriaMessageToolbar: View {
    let model: AriaAgentMessageViewModel
    let message: AriaAgentMessage

    var body: some View {
        HStack(spacing: 2) {
            Button { model.copy(message) } label: {
                Image(systemName: model.copied ? "checkmark" : "doc.on.doc")
            }
            .accessibilityLabel("Copy")
            Button { model.readAloud(message) } label: {
                Image(systemName: "speaker.wave.2")
            }
            .accessibilityLabel("Read aloud")
            Button { model.voteUp(message) } label: {
                Image(systemName: message.vote == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .accessibilityLabel("Good answer")
            Button { model.voteDown(message) } label: {
                Image(systemName: message.vote == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }
            .accessibilityLabel("Bad answer")
            Button { model.regenerate(message) } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Regenerate")
            .disabled(!model.canRegenerate)
            Spacer()
            if let usage = model.usageText(message) {
                Text(verbatim: usage)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .buttonStyle(AriaIconButtonStyle())
        // Cinque pulsanti e i token in riga: oltre xxxLarge smettono di crescere per non uscire dalla bolla.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.leading, -8)
    }
}

/// I chip di follow-up sotto l'ultima risposta: un tocco manda il prompt.
struct AriaMessageFollowUps: View {
    let chips: [AriaChatCopy.FollowUp]
    let isEnabled: Bool
    var onSend: (AriaChatCopy.FollowUp) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button { onSend(chip) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right").font(.caption2.weight(.semibold))
                            Text(chip.label).font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                }
            }
        }
    }
}

/// Icona piccola ma con un'area di tocco da 36 pt (si usa anche con i guanti); cresce con l'icona.
struct AriaIconButtonStyle: ButtonStyle {
    @ScaledMetric(relativeTo: .footnote) private var side: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}
