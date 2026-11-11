//
//  AriaReassignmentPlanCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La card `reassignment-plan` in chat: titolo e sintesi, "Applica tutto", il carico delle squadre e una
//  riga per ogni mossa proposta. Lo stato e la logica stanno in AriaReassignmentPlanViewModel.
//

import SwiftUI

struct AriaReassignmentPlanCard: View {
    let model: AriaReassignmentPlanViewModel

    var body: some View {
        AriaCard {
            header
            if !model.plan.teams.isEmpty { teamLoad }
            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let summary = model.summary {
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            if model.isBalanced {
                balanced
            } else if model.allDismissed {
                Text("All suggestions dismissed")
                    .font(.footnote.italic())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            ForEach(model.visibleMoves) { AriaReassignmentMoveRow(move: $0, model: model) }
        }
        .animation(.snappy(duration: 0.2), value: model.visibleMoves.count)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Reassignment plan").font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "arrow.left.arrow.right").foregroundStyle(Color.liteAccent)
            }
            if let headline = model.plan.headline {
                Text(AriaMarkdown.inline(headline)).font(.footnote).foregroundStyle(.secondary)
            }
            if model.showsApplyAll {
                Button { model.applyAll() } label: {
                    HStack(spacing: 6) {
                        if model.isApplyingAll { ProgressView().controlSize(.small) } else { Image(systemName: "checkmark") }
                        Text("Apply all (\(model.pendingCount))")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 6)
                    .frame(minHeight: 34)
                }
                .ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
                .buttonBorderShape(.capsule)
                .disabled(model.isWorking)
            }
        }
    }

    private var teamLoad: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Team load")
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            AriaFlowLayout(spacing: 6) {
                ForEach(model.plan.teams) { AriaTeamLoadChip(team: $0) }
            }
        }
    }

    private var balanced: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
            Text("The teams are balanced").font(.footnote.weight(.semibold))
            Text("No work order needs to change team right now.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

extension AriaLoadTone {
    /// Mai rosso: il rosso è solo per gli errori.
    var color: Color {
        switch self {
        case .calm: .green
        case .busy: .yellow
        case .full: .orange
        }
    }
}

private struct AriaTeamLoadChip: View {
    let team: AriaReassignmentPlan.TeamLoad

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill").font(.caption2).foregroundStyle(team.tone.color)
            Text(team.name).font(.caption).lineLimit(1)
            if team.isAdHoc {
                Text("Ad hoc").font(.caption2).foregroundStyle(.secondary)
            }
            Text(verbatim: "\(team.loadPct)%").font(.caption.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(team.tone.color.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(team.tone.color.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
