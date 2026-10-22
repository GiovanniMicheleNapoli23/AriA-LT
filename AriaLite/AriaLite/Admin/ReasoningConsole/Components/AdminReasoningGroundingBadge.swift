//
//  AdminReasoningGroundingBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il grounding di un turno come pillola colorata: verde se la risposta poggia sulle fonti, arancio
//  se in parte, rosso se poco.
//

import SwiftUI

struct AdminReasoningGroundingBadge: View {
    let score: Double

    private var tint: Color {
        switch score {
        case 0.7...: .green
        case 0.4..<0.7: .orange
        default: .red
        }
    }

    var body: some View {
        Label {
            Text(AdminReasoningFormat.percent(score) ?? "")
        } icon: {
            Image(systemName: "checkmark.seal.fill")
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityLabel(Text("Grounding \(AdminReasoningFormat.percent(score) ?? "")"))
    }
}
