//
//  AriaCreditsBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una barra dei crediti nel foglio: titolo e valore sopra, la barra con un segno alla soglia d'avviso, due righe
//  sotto (es. "Resets 1 Dec" e "7% used") e una nota. Si legge come un'unica frase per VoiceOver.
//

import SwiftUI

struct AriaCreditsBar: View {
    let content: AriaCreditsBarContent
    let tint: Color

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            AriaCreditsMeter(fill: content.fill, tick: content.tick, tint: tint)
            if content.leading != nil || content.trailing != nil { footer }
            if let note = content.note {
                Text(verbatim: note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(verbatim: content.title).font(.subheadline.weight(.semibold))
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(verbatim: content.value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            if let leading = content.leading { Text(verbatim: leading) }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            if let trailing = content.trailing { Text(verbatim: trailing).monospacedDigit() }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// Il binario e il riempimento, col segno della soglia (nessun numero: la barra è un aiuto visivo).
struct AriaCreditsMeter: View {
    let fill: Double
    let tick: Double?
    let tint: Color

    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(tint)
                    .frame(width: max(fill > 0 ? height : 0, proxy.size.width * fill))
                if let tick {
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: 2, height: height + 6)
                        .offset(x: proxy.size.width * tick - 1)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + 6)
        .animation(.smooth(duration: 0.4), value: fill)
        .accessibilityHidden(true)
    }
}
