//
//  AdminScenarioBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un'etichetta colorata (verdetto, stato, maturità…) e il colore di ogni tono della sezione.
//

import SwiftUI

struct AdminScenarioBadge: View {
    let text: String
    var tone: AdminScenarioTone = .neutral
    var systemImage: String?

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tone.color.opacity(0.1), in: Capsule())
        .fixedSize()
    }
}

extension AdminScenarioTone {
    /// Toni spenti: il colore accompagna il dato, non lo urla. Il positivo è l'accento (bianco lilla in
    /// scuro), non il verde; il negativo è grigio, non il rosso.
    var color: Color {
        switch self {
        case .positive: .liteAccent
        case .warning: .liteWarning
        case .negative: .secondary
        case .info: .liteAccent
        case .neutral: .secondary
        }
    }
}
