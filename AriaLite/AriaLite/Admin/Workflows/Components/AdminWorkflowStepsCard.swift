//
//  AdminWorkflowStepsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il grafo del flusso come lista di passi, nell'ordine in cui il flusso li percorre. Sola lettura:
//  il grafo si disegna e si modifica dalla web.
//

import SwiftUI

struct AdminWorkflowStepsCard: View {
    let steps: [AdminWorkflowStep]

    var body: some View {
        AdminCard(title: "Steps", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
            VStack(alignment: .leading, spacing: 14) {
                if steps.isEmpty {
                    Text("This flow has no steps yet. Build its graph from the web app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        if index > 0 { Divider() }
                        AdminWorkflowStepRow(number: index + 1, step: step)
                    }
                    Text("Read-only: edit the graph from the web app.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

/// Un passo: tipo e nome, l'agente se c'è, il gruppo che lo contiene e le sue uscite ("→ Passo").
struct AdminWorkflowStepRow: View {
    let number: Int
    let step: AdminWorkflowStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteAccent)
                .frame(minWidth: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if step.isUnavailable {
                    Label("Not available on this server", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                ForEach(step.connections) { connection in
                    connectionLine(connection)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// "Agent · inside Group": il tipo, l'agente e il gruppo.
    private var subtitle: String {
        var parts = [step.kindLabel]
        if let detail = step.detail { parts.append(detail) }
        if let group = step.groupTitle { parts.append(String(localized: "in \(group)")) }
        return parts.joined(separator: " · ")
    }

    private func connectionLine(_ connection: AdminWorkflowStep.Connection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: "→")
                .foregroundStyle(Color.liteAccent)
            if let label = connection.label {
                Text(verbatim: "\(connection.targetTitle) (\(label))")
            } else {
                Text(verbatim: connection.targetTitle)
            }
        }
        .font(.footnote)
        .foregroundStyle(.primary)
    }
}
