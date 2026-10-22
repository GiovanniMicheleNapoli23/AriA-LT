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
        .font(.caption2.weight(.bold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tone.color.opacity(0.14), in: Capsule())
        .fixedSize()
    }
}

extension AdminScenarioTone {
    var color: Color {
        switch self {
        case .positive: .green
        case .warning: .orange
        case .negative: .red
        case .info: .liteAccent
        case .neutral: .secondary
        }
    }
}
