//
//  AriaLearningViews.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Il Real-time Learning della web, sul telefono: quando Aria non è sicura di una risposta l'avviso esce
//  dalla Dynamic Island (AriaIsland) e la domanda prende il posto del composer (AriaElicitationPanel,
//  variante `.learning`). Qui ci sono l'identità visiva, la card che la sostituisce quando si è risposto
//  (learning-learned-card della web) e il chip per riaprirla da una risposta precedente (ValidationChip).
//

import SwiftUI

enum AriaLearningStyle {
    static let tint = Color.purple
    static let symbol = "graduationcap.fill"
}

struct AriaLearningIcon: View {
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: AriaLearningStyle.symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(AriaLearningStyle.tint.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

/// "Real-time Learning" nell'intestazione del pannello.
struct AriaLearningBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            AriaLearningIcon()
            Text("Real-time Learning")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AriaLearningStyle.tint)
        }
    }
}

// MARK: - Chip

/// Sotto una risposta di cui Aria non è sicura: riapre la sua domanda di Real-time Learning.
struct AriaLearningChip: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                AriaLearningIcon(size: 20)
                Text("Aria isn't sure — help it learn")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AriaLearningStyle.tint)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AriaLearningStyle.tint.opacity(0.7))
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(AriaLearningStyle.tint.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(AriaLearningStyle.tint.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
