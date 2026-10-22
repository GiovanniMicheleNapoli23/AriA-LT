//
//  AriaChatEmptyState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La chat vuota: sfera, saluto e suggerimenti iniziali, disposti secondo lo spazio libero.
//

import SwiftUI

/// La sfera e il saluto: mentre l'operatore scrive la sfera "pensa", e all'invio vola al posto
/// della sfera piccola sotto la risposta (stesso `matchedGeometryEffect`) mentre il saluto sparisce.
struct AriaChatEmptyState: View {
    let model: AriaAgentChatViewModel
    let orbNamespace: Namespace.ID
    var onSelectSuggestion: (String) -> Void

    /// Entrata del saluto.
    @State private var appeared = false

    private var layout: AriaChatEmptyLayout { model.emptyLayout }

    private var spacing: CGFloat {
        switch layout {
        case .regular: 24
        case .compact, .minimal: 12
        case .suggestionsOnly, .hidden: 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: spacing)

            if layout.showsOrb {
                AriaOrb(mood: model.isComposing ? .thinking : .idle, radius: 0.8)
                    .ariaOrbHero(orbNamespace)
                    .frame(width: layout.isCompact ? 56 : 88, height: layout.isCompact ? 56 : 88)
                    .shadow(color: Color.accentColor.opacity(0.22), radius: 16, x: 0, y: 8)
                    .background { AriaOrbGlow() }
            }

            if layout.showsGreeting {
                greeting
            }

            if !model.suggestions.isEmpty && layout.showsSuggestions {
                AriaChatSuggestionCards(suggestions: model.suggestions,
                                        isCompact: layout.isCompact,
                                        isEnabled: model.canSendSuggestion,
                                        onSelect: onSelectSuggestion)
                    .padding(.top, layout.showsOrb ? (layout.isCompact ? 18 : 28) : 0)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer(minLength: spacing)
        }
        .animation(.smooth(duration: 0.4), value: model.suggestions)
        .animation(.smooth(duration: 0.3), value: layout)
        .task { withAnimation(.smooth(duration: 0.6).delay(0.05)) { appeared = true } }
        .task(id: model.backend.isReady) { await model.loadSuggestions() }
    }

    private var greeting: some View {
        VStack(spacing: 8) {
            if !layout.isCompact {
                Text(model.salutation)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(model.greeting)
                .font((layout.isCompact ? Font.title2 : Font.title).weight(.semibold))
                .tracking(-0.4)
                .foregroundStyle(.primary.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(layout.isCompact ? 2 : 3)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 32)
        .padding(.top, layout.isCompact ? 14 : 26)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .transition(.opacity)
    }
}
