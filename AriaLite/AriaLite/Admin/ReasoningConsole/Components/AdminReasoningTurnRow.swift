//
//  AdminReasoningTurnRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un turno nella timeline della sessione: numero, ora, domanda, durata, nodi e grounding.
//  La linea a sinistra lega i turni uno sotto l'altro.
//

import SwiftUI

struct AdminReasoningTurnRow: View {
    let turn: AdminReasoningTurnSummary
    var isLast = false

    @ScaledMetric(relativeTo: .caption) private var dotSize = 26

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(turn.episodeNumber.map { "\($0)" } ?? "•")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.liteAccent)
                    .frame(width: dotSize, height: dotSize)
                    .background(Color.liteAccent.opacity(0.12), in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.liteAccent.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            card
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if let created = turn.created {
                    Text(created, format: .dateTime.hour().minute().second())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let score = turn.groundingScore { AdminReasoningGroundingBadge(score: score) }
            }
            Text(AdminReasoningFormat.trimmed(turn.question) ?? String(localized: "No question recorded"))
                .font(.subheadline)
                .foregroundStyle(turn.question == nil ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            metrics
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 14))
        .padding(.bottom, isLast ? 0 : 10)
    }

    /// Durata, nodi, agente e avvisi: vanno a capo invece di tagliarsi.
    private var metrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { metricItems }
            VStack(alignment: .leading, spacing: 4) { metricItems }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var metricItems: some View {
        if let duration = AdminReasoningFormat.duration(ms: turn.durationMs) {
            Label(duration, systemImage: "timer")
        }
        if let nodes = turn.nodeCount {
            Label("\(nodes) nodes", systemImage: "point.3.connected.trianglepath.dotted")
        }
        if let agent = AdminReasoningFormat.trimmed(turn.agent) {
            Label(agent, systemImage: "cpu").lineLimit(1)
        }
        if let ungrounded = turn.ungroundedCount, ungrounded > 0 {
            Label("\(ungrounded) ungrounded", systemImage: "exclamationmark.bubble")
                .foregroundStyle(.orange)
        }
        if turn.contextVoided == true {
            Label("Context voided", systemImage: "xmark.bin").foregroundStyle(.orange)
        }
    }
}
