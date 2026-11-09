//
//  AriaChatSuggestionCards.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I suggerimenti iniziali della chat vuota come card di vetro (al massimo 4), in una griglia adattiva.
//

import SwiftUI

/// Griglia adattiva: due colonne su iPhone, di più dove c'è larghezza (iPad, orizzontale). Mai una riga
/// scorrevole: se lo spazio in altezza è poco (tastiera aperta, schermi bassi) si mostrano i primi due.
/// Un tocco manda il suggerimento come primo messaggio.
struct AriaChatSuggestionCards: View {
    let suggestions: [String]
    /// Poco spazio: card più basse (due righe) e, se serve, solo i primi due suggerimenti.
    let isCompact: Bool
    let isEnabled: Bool
    var onSelect: (String) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: sizeClass == .regular ? 220 : 150), spacing: 10)]
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            grid(suggestions)
            grid(Array(suggestions.prefix(2)))
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 760)
    }

    private func grid(_ items: [String]) -> some View {
        AriaGlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items, id: \.self) { suggestion in
                    card(suggestion)
                }
            }
        }
    }

    private func card(_ suggestion: String) -> some View {
        Button {
            onSelect(suggestion)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                // Righe sempre riservate: le card della stessa riga hanno la stessa altezza.
                Text(suggestion)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isCompact ? 2 : 3, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, isCompact ? 10 : 12)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .ariaGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(suggestion)
        .accessibilityIdentifier("chat.suggestion")
    }
}
