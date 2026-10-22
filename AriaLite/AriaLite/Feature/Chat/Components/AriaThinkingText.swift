//
//  AriaThinkingText.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Thinking" sotto la sfera finché Aria non scrive.
//

import SwiftUI

/// "Thinking" con una luce che scorre sul testo, al posto dei tre pallini.
struct AriaThinkingText: View {
    var label: LocalizedStringKey = "Thinking"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let period = 1.8
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
            // La luce entra da sinistra ed esce a destra (oltre i bordi del testo).
            let x = reduceMotion ? 0.5 : -0.4 + phase * 1.8

            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(shine(at: x, base: Color(.systemGray3), light: Color(.systemGray)))
        }
        .padding(.vertical, 6)
        .accessibilityLabel(Text(label))
    }

    /// Gradiente largo il doppio del testo, con la luce al centro: spostandolo, la luce scorre.
    private func shine(at x: Double, base: Color, light: Color) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: base, location: 0),
            .init(color: base, location: 0.3),
            .init(color: light, location: 0.5),
            .init(color: base, location: 0.7),
            .init(color: base, location: 1),
        ], startPoint: UnitPoint(x: x - 1, y: 0.5), endPoint: UnitPoint(x: x + 1, y: 0.5))
    }
}
