//
//  AriaReassignmentMoveRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Una mossa del piano di riassegnazione: l'ordine di lavoro, da quale squadra a quale, il perché e i pulsanti
//  Rifiuta / Accetta (o "Applicato" a cose fatte).
//

import SwiftUI

struct AriaReassignmentMoveRow: View {
    let move: AriaReassignmentPlan.Move
    let model: AriaReassignmentPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(move.title).font(.subheadline.weight(.semibold))
            tags
            meta
            route
            if let motivation = move.motivation {
                Label {
                    Text(AriaMarkdown.inline(motivation)).font(.footnote)
                } icon: {
                    Image(systemName: "sparkles").font(.caption).foregroundStyle(Color.liteAccent)
                }
            }
            actions
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if model.isApplied(move) {
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.green.opacity(0.4), lineWidth: 1)
            }
        }
    }

    // MARK: Parti

    @ViewBuilder
    private var tags: some View {
        if move.priority != nil || move.assetTag != nil {
            AriaFlowLayout(spacing: 6) {
                if let priority = move.priority { capsule(Self.priorityTitle(priority), tone: Self.priorityTone(priority)) }
                if let tag = move.assetTag {
                    Text(tag)
                        .font(.caption2.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1))
                }
            }
        }
    }

    /// Categoria · durata · scadenza; una scadenza passata ha il triangolo arancione.
    @ViewBuilder
    private var meta: some View {
        let parts = metaParts
        if !parts.isEmpty || move.dueDate != nil {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if move.isOverdue() {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Overdue")
                }
                Text(parts.joined(separator: " · "))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var metaParts: [String] {
        var parts: [String] = []
        if let category = move.category { parts.append(category.capitalized) }
        if let minutes = move.estimatedMinutes { parts.append("\(minutes) min") }
        if let due = move.dueDate { parts.append(due.formatted(.dateTime.day().month(.abbreviated))) }
        return parts
    }

    /// "Squadra (carico) → squadra (carico)"; a testo grande le due squadre vanno una sotto l'altra.
    private var route: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { fromLabel; arrow; toLabel }
            VStack(alignment: .leading, spacing: 4) { fromLabel; arrow; toLabel }
        }
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.quaternarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var arrow: some View {
        Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(Color.liteAccent)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fromLabel: some View {
        if let name = move.fromTeamName {
            Text(Self.teamText(name, pct: move.fromLoadPct))
        } else {
            Text("Unassigned").italic().foregroundStyle(.secondary)
        }
    }

    private var toLabel: some View {
        HStack(spacing: 4) {
            Text(Self.teamText(move.toTeamName, pct: move.toLoadPct)).fontWeight(.semibold)
            if move.toIsAdHoc {
                Text("Ad hoc").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        Group {
            if model.isApplied(move) {
                Label("Applied", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { rejectButton; acceptButton }
                    VStack(alignment: .leading, spacing: 8) { rejectButton; acceptButton }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var rejectButton: some View {
        Button { model.reject(move) } label: {
            Text("Reject").font(.footnote.weight(.semibold)).padding(.horizontal, 6).frame(minHeight: 32)
        }
        .ariaGlassButtonStyle()
        .buttonBorderShape(.capsule)
        .disabled(model.isWorking)
    }

    @ViewBuilder
    private var acceptButton: some View {
        if model.canAccept {
            Button { model.accept(move) } label: {
                HStack(spacing: 6) {
                    if model.isBusy(move) { ProgressView().controlSize(.small) } else { Image(systemName: "checkmark") }
                    Text("Accept")
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 6)
                .frame(minHeight: 32)
            }
            .ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
            .buttonBorderShape(.capsule)
            .disabled(model.isWorking)
        }
    }

    // MARK: Aiuti

    private func capsule(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tone.opacity(0.18), in: Capsule())
    }

    private static func teamText(_ name: String, pct: Int?) -> String {
        pct.map { "\(name) (\($0)%)" } ?? name
    }

    private static func priorityTitle(_ value: String) -> String {
        switch value {
        case "high": String(localized: "High")
        case "medium": String(localized: "Medium")
        case "low": String(localized: "Low")
        default: value.capitalized
        }
    }

    /// Mai rosso: alta arancione, media gialla, bassa verde.
    private static func priorityTone(_ value: String) -> Color {
        switch value {
        case "high": .orange
        case "medium": .yellow
        case "low": .green
        default: .secondary
        }
    }
}
