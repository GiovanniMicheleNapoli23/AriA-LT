//
//  AriaSettingsCreditsRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  La riga dei crediti: l'anello della quota al posto del simbolo, il saldo e la ricarica sotto. Se il saldo non si
//  legge, "Credits unavailable": la pagina che apre ha "Try again".
//

import SwiftUI

struct AriaSettingsCreditsRow: View {
    let model: AriaCreditsViewModel

    @ScaledMetric(relativeTo: .body) private var ringSide: CGFloat = 22

    var body: some View {
        Group {
            if let card = model.card, !model.isFailed {
                Label {
                    texts(Text(verbatim: card.headline), card.subline.map { Text(verbatim: $0) })
                } icon: {
                    AriaCreditsRing(fraction: card.fraction, tint: model.tint(card.tone), isMuted: card.isMuted)
                        .frame(width: ringSide, height: ringSide)
                }
            } else {
                Label {
                    texts(Text("Credits unavailable"), Text("Chat keeps working"))
                } icon: {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.cardAccessibilityLabel)
        .accessibilityIdentifier("settings.credits")
    }

    private func texts(_ title: Text, _ subtitle: Text?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            if let subtitle {
                subtitle.font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
