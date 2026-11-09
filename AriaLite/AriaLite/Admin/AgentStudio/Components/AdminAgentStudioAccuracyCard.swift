//
//  AdminAgentStudioAccuracyCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'accuratezza di ogni agente sulle ultime risposte valutate (agent-accuracy): punteggio con barra,
//  quante risposte valutate e quante fondate sulle fonti. È una stima del valutatore, e si dice.
//

import SwiftUI

struct AdminAgentStudioAccuracyCard: View {
    let agents: [AdminAgentStudioAgentAccuracy]
    let window: Int?
    let errorMessage: String?

    var body: some View {
        AdminCard(title: "Agent accuracy", systemImage: "scope") {
            VStack(alignment: .leading, spacing: 12) {
                if agents.isEmpty {
                    AdminSectionNotice(text: errorMessage ?? String(localized: "No graded answers yet."),
                                       systemImage: "scope", isError: errorMessage != nil)
                } else {
                    ForEach(agents) { agent in
                        row(agent)
                    }
                    if let window {
                        Text("Estimated by a second model over each agent's last \(window) graded answers.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func row(_ agent: AdminAgentStudioAgentAccuracy) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(agent.agent)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(agent.score)%")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(color(for: agent.score))
            }
            ProgressView(value: Double(min(max(agent.score, 0), 100)), total: 100)
                .tint(color(for: agent.score))
            Text("\(agent.graded) graded · \(agent.grounded) grounded")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func color(for score: Int) -> Color {
        switch score {
        case 80...: .green
        case 60..<80: .orange
        default: .red
        }
    }
}
