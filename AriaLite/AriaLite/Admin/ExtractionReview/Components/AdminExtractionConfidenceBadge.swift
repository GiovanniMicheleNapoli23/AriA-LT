//
//  AdminExtractionConfidenceBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Quanto è sicura l'estrazione dell'AI, come percentuale colorata: rossa sotto il 50%, arancio sotto
//  l'80%, verde sopra. I valori bassi sono quelli da guardare con più attenzione.
//

import SwiftUI

struct AdminExtractionConfidenceBadge: View {
    let confidence: Double

    private var color: Color { AdminExtractionTone.confidence(confidence) }

    var body: some View {
        Label {
            Text(confidence.formatted(.percent.precision(.fractionLength(0))))
        } icon: {
            Image(systemName: "sparkles")
        }
        .labelStyle(.titleAndIcon)
        .font(.caption2.weight(.bold).monospacedDigit())
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .fixedSize()
        .accessibilityLabel(Text("AI confidence \(confidence.formatted(.percent.precision(.fractionLength(0))))"))
    }
}
