//
//  AriaCreditsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La card dei crediti nel profilo: un anello (la quota giornaliera che resta), il titolo ("27.6 credits available"),
//  la riga sotto ("refills in 3 h") e la freccia. Se il saldo non si legge dice "Credits unavailable" e il tocco
//  riprova. Il tono è dell'anello: normale = accento, avviso = ambra, tetto raggiunto = grigio, mai rosso.
//  Lo sfondo e il tocco li mette il profilo, come per le altre card.
//

import SwiftUI

struct AriaCreditsCard: View {
    let model: AriaCreditsViewModel
    /// Nel profilo "settings.credits", nel menu "···" della chat "options.credits".
    var identifier = "settings.credits"

    @ScaledMetric(relativeTo: .body) private var ringSide: CGFloat = 34

    var body: some View {
        HStack(spacing: 12) {
            leading
            texts
            Spacer(minLength: 8)
            trailing
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.cardAccessibilityLabel)
        .accessibilityHint(model.cardAccessibilityHint)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var leading: some View {
        if let card = model.card, !model.isFailed {
            AriaCreditsRing(fraction: card.fraction, tint: model.tint(card.tone), isMuted: card.isMuted)
                .frame(width: ringSide, height: ringSide)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        } else {
            Image(systemName: "exclamationmark.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: ringSide, height: ringSide)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var texts: some View {
        if let card = model.card, !model.isFailed {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: card.headline).font(.body.weight(.medium))
                if let subline = card.subline {
                    Text(verbatim: subline).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Credits unavailable").font(.body.weight(.medium))
                Text("Chat keeps working").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if model.isFailed {
            Image(systemName: "arrow.clockwise")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

/// L'anello: il binario e l'arco della quota che resta. Senza quota giornaliera è un cerchio pieno e spento.
struct AriaCreditsRing: View {
    let fraction: Double
    let tint: Color
    var isMuted = false

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(isMuted ? Color.secondary.opacity(0.35) : tint,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.5), value: fraction)
        }
        .accessibilityHidden(true)
    }
}
