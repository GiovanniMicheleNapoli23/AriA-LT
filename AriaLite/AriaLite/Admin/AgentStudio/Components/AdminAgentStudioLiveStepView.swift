//
//  AdminAgentStudioLiveStepView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Un passo del run in una linea verticale numerata: stato, motivo e metriche; al tocco si apre con motivo intero e uscita.
//

import SwiftUI

struct AdminAgentStudioLiveStepView: View {
    let row: AdminAgentStudioLiveStepRow
    var isLast = false
    let isExpanded: Bool
    let onToggle: () -> Void

    /// Solo l'uscita aperta del singolo passo: stato di sola presentazione.
    @State private var showsFullOutput = false
    @ScaledMetric(relativeTo: .subheadline) private var bubble: CGFloat = 26

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                AdminAgentStudioLiveStepMarker(state: row.state, index: row.index, side: bubble)
                if !isLast { AdminAgentStudioStepConnector(isSolid: row.isFinished) }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                summary
                if isExpanded, row.isExpandable { expandedArea }
                if row.state == .needsApproval, let approvalId = row.approvalId { approvalLink(approvalId) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 3)
            .padding(.bottom, isLast ? 0 : 16)
        }
        .opacity(row.state == .skipped ? 0.6 : 1)
        .animation(.snappy, value: row.state)
        .animation(.snappy, value: isExpanded)
    }

    // MARK: Riga

    @ViewBuilder
    private var summary: some View {
        if row.isExpandable {
            Button(action: onToggle) { summaryContent }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? Text("Hides the details") : Text("Shows the details"))
        } else {
            summaryContent
        }
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(row.state == .waiting ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if row.showsStateTag { AdminAgentStudioBadge(status: row.statusKey) }
                if row.isExpandable {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            if let subtitle = row.subtitle, row.state == .waiting || row.state == .running {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            if row.state == .running { runningLine }
            if row.isFinished, !isExpanded, let reason = row.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            if row.isFinished, let metrics = row.metricsLine {
                Text(metrics)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.accessibilityTitle)
        .accessibilityValue(row.reason ?? "")
    }

    private var runningLine: some View {
        HStack(spacing: 8) {
            Text("Working…")
            if let attempt = row.attempt, attempt > 1 {
                Text("Retry \(attempt)")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.liteAccent)
    }

    // MARK: Parte aperta

    private var expandedArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reason = row.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let output = row.displayOutput { outputBox(output) }
        }
    }

    private func outputBox(_ output: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(output)
                .font(.caption.monospaced())
                .lineLimit(showsFullOutput ? nil : 12)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if row.outputIsLong {
                Button {
                    showsFullOutput.toggle()
                } label: {
                    showsFullOutput ? Text("Show less") : Text("Show more")
                }
                .font(.caption.weight(.semibold))
                .tint(Color.liteAccent)
            }
        }
    }

    private func approvalLink(_ approvalId: String) -> some View {
        NavigationLink(value: AdminAgentStudioRoute.approval(id: approvalId)) {
            Label("Review approval", systemImage: "hand.raised")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.orange)
    }
}
