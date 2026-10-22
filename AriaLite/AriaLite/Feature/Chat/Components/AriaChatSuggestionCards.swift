//
//  AriaChatSuggestionCards.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I suggerimenti iniziali della chat vuota come card di vetro (al massimo 4).
//

import SwiftUI

/// Griglia 2×2 quando c'è spazio, riga scorrevole quando è poco (tastiera aperta, schermi bassi).
/// Un tocco manda il suggerimento come primo messaggio.
struct AriaChatSuggestionCards: View {
    let suggestions: [String]
    let isScrollingRow: Bool
    let isEnabled: Bool
    var onSelect: (String) -> Void

    var body: some View {
        if isScrollingRow {
            ScrollView(.horizontal) {
                AriaGlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            card(suggestion).frame(width: 210)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .contentMargins(.horizontal, 24, for: .scrollContent)
        } else {
            AriaGlassEffectContainer(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        card(suggestion)
                    }
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
        }
    }

    private func card(_ suggestion: String) -> some View {
        Button {
            onSelect(suggestion)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                // Tre righe sempre riservate: le card hanno tutte la stessa altezza.
                Text(suggestion)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .ariaGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(suggestion)
        .accessibilityIdentifier("chat.suggestion")
    }
}
