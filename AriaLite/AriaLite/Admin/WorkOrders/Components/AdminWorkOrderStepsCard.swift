//
//  AdminWorkOrderStepsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I passi della procedura: numero, testo, esito (fatto, non fatto o da fare), nota, chi l'ha registrato e
//  le foto, con l'avanzamento in testa. Se l'ordine è aperto l'admin spunta un passo toccando il cerchio e
//  dal menu del passo registra "fatto"/"non fatto" con una nota o toglie il risultato; dal menu in testa
//  spunta o azzera tutti i passi. La logica è in AdminWorkOrderStepActions.
//

import SwiftUI

struct AdminWorkOrderStepsCard: View {
    let steps: [AdminWorkOrderStepRowItem]
    let progress: (fraction: Double, text: String)?
    /// `nil`: sola lettura (ordine chiuso, o chi lo mostra non permette modifiche).
    var actions: AdminWorkOrderStepActions?
    var canReset = false

    /// Il cerchio del numero cresce col testo (Dynamic Type).
    @ScaledMetric(relativeTo: .caption) private var markerSize: CGFloat = 20
    /// L'area del menu "…" cresce col glifo.
    @ScaledMetric(relativeTo: .footnote) private var menuSide: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                AdminWorkOrderCardTitle(title: String(localized: "Steps"), icon: "list.bullet.clipboard")
                Spacer(minLength: 0)
                if let progress {
                    Text(progress.text)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let actions { bulkMenu(actions) }
            }
            if let progress { AdminWorkOrderProgressBar(fraction: progress.fraction, height: 3) }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    row(step)
                    if index < steps.count - 1 { Divider().padding(.leading, markerSize + 10) }
                }
            }
        }
        .adminWorkOrderCard()
    }

    // MARK: Menu di tutti i passi

    private func bulkMenu(_ actions: AdminWorkOrderStepActions) -> some View {
        Menu {
            Button("Check all steps", systemImage: "checklist.checked") { Task { await actions.checkAll() } }
            if canReset {
                Button("Reset all checks", systemImage: "arrow.counterclockwise", role: .destructive) {
                    actions.confirmReset()
                }
            }
        } label: {
            if actions.isBulkBusy {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: "ellipsis.circle").imageScale(.medium)
            }
        }
        .disabled(actions.isBulkBusy)
        .accessibilityLabel(Text("Step actions"))
    }

    // MARK: Un passo

    private func row(_ step: AdminWorkOrderStepRowItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            marker(step)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.text)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                if let status = step.status {
                    Text(status.localized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(color(status))
                }
                if let note = step.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.liteAccent.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }
                if step.byline != nil || step.photoCount > 0 {
                    HStack(spacing: 8) {
                        if let byline = step.byline { Text(byline) }
                        if step.photoCount > 0 {
                            Label(String(localized: "\(step.photoCount) photos"), systemImage: "photo")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if let actions { stepMenu(step, actions) }
        }
        .padding(.vertical, 7)
    }

    private func stepMenu(_ step: AdminWorkOrderStepRowItem, _ actions: AdminWorkOrderStepActions) -> some View {
        Menu {
            Button("Done…", systemImage: "checkmark.circle") { actions.startReport(step, status: .done) }
            Button("Not done…", systemImage: "xmark.circle") { actions.startReport(step, status: .notDone) }
            if step.status != nil {
                Divider()
                Button("Clear result", systemImage: "trash", role: .destructive) { actions.confirmClear(step) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: menuSide, height: menuSide)
                .contentShape(Rectangle())
        }
        .disabled(actions.isBusy(step))
        .accessibilityLabel(Text("Step \(step.number) actions"))
    }

    /// Il cerchio a sinistra: con le azioni è la spunta del passo.
    @ViewBuilder
    private func marker(_ step: AdminWorkOrderStepRowItem) -> some View {
        if let actions {
            Button { actions.toggle(step) } label: { markerImage(step, isBusy: actions.isBusy(step)) }
                .buttonStyle(.plain)
                .disabled(actions.isBusy(step))
                .accessibilityLabel(Text(step.status == .done ? "Uncheck step \(step.number)" : "Check step \(step.number)"))
        } else {
            markerImage(step, isBusy: false)
        }
    }

    private func markerImage(_ step: AdminWorkOrderStepRowItem, isBusy: Bool) -> some View {
        Group {
            if isBusy {
                ProgressView().controlSize(.small)
            } else {
                switch step.status {
                case .done?:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .notDone?:
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.orange)
                default:
                    Text(verbatim: "\(step.number)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.liteAccent)
                        .frame(width: markerSize, height: markerSize)
                        .overlay(Circle().strokeBorder(Color.liteAccent.opacity(0.3), lineWidth: 1))
                }
            }
        }
        .font(.system(size: markerSize))
        .frame(width: markerSize + 2, height: markerSize + 2)
        .contentShape(Circle())
    }

    private func color(_ status: AdminWorkOrderStepStatus) -> Color {
        switch status {
        case .done: .green
        case .notDone: .orange
        case .unknown: .secondary
        }
    }
}
