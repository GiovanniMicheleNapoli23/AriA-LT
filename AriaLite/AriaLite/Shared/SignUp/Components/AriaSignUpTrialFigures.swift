//
//  AriaSignUpTrialFigures.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le cifre della prova (utenti, crediti AI al giorno, GB di knowledge base) in tessere affiancate che vanno a
//  capo con i testi grandi, e le barre grigie che le sostituiscono mentre il listino arriva.
//

import SwiftUI

/// Una barra grigia al posto di una cifra non ancora arrivata.
struct AriaSignUpPlaceholderBar: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.liteText.opacity(0.08))
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

struct AriaSignUpTrialFigures: View {
    let figures: [AriaTrialOffer.Figure]
    @ScaledMetric(relativeTo: .caption) private var tileMinimum: CGFloat = 84

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: 8, alignment: .top)], spacing: 8) {
            ForEach(figures) { figure in
                VStack(alignment: .leading, spacing: 2) {
                    Text(figure.value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.liteText)
                    Text(figure.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color.liteText.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Tre tessere vuote mentre il listino arriva: nascoste a VoiceOver.
struct AriaSignUpTrialFiguresPlaceholder: View {
    @ScaledMetric(relativeTo: .caption) private var tileMinimum: CGFloat = 84

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinimum), spacing: 8)], spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    AriaSignUpPlaceholderBar(width: 36, height: 20)
                    AriaSignUpPlaceholderBar(width: 56, height: 10)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.liteText.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .accessibilityHidden(true)
    }
}
