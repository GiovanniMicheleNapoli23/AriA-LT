//
//  AdminAgentStudioBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Uno stato o un esito di Agent Studio come pastiglia colorata (completato verde, bloccato rosso…).
//

import SwiftUI

struct AdminAgentStudioBadge: View {
    let text: String
    let tone: AdminAgentStudioTone

    init(text: String, tone: AdminAgentStudioTone) {
        self.text = text
        self.tone = tone
    }

    /// Etichetta e tono dal valore grezzo del server.
    init(status: String) {
        self.init(text: AdminAgentStudioStatus.label(for: status), tone: AdminAgentStudioStatus.tone(for: status))
    }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tone.color.opacity(0.14), in: Capsule())
            .fixedSize()
    }
}

extension AdminAgentStudioTone {
    /// Il colore del tono, uguale per pastiglie e tessere.
    var color: Color {
        switch self {
        case .positive: .green
        case .warning: .orange
        case .negative: .red
        case .active: .blue
        case .neutral: .secondary
        }
    }
}
