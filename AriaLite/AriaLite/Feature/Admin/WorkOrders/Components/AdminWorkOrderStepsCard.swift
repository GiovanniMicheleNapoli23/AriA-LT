//
//  AdminWorkOrderStepsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I passi della procedura in sola lettura: numero, testo, esito (fatto, non fatto o da fare), nota,
//  chi l'ha registrato e le foto. In testa l'avanzamento.
//

import SwiftUI

struct AdminWorkOrderStepsCard: View {
    let steps: [AdminWorkOrderStepRowItem]
    let progress: (fraction: Double, text: String)?

    /// Il cerchio del numero cresce col testo (Dynamic Type).
    @ScaledMetric(relativeTo: .caption) private var markerSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                AdminWorkOrderCardTitle(title: String(localized: "Steps"), icon: "list.bullet.clipboard")
                Spacer()
                if let progress {
                    Text(progress.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let progress { AdminWorkOrderProgressBar(fraction: progress.fraction) }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    row(step)
                    if index < steps.count - 1 { Divider().padding(.leading, markerSize + 12) }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ step: AdminWorkOrderStepRowItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            marker(step)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if let status = step.status {
                    Text(status.localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color(status))
                }
                if let note = step.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.liteAccent.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
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
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func marker(_ step: AdminWorkOrderStepRowItem) -> some View {
        Group {
            switch step.status {
            case .done?:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .notDone?:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.orange)
            default:
                Text(verbatim: "\(step.number)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liteAccent)
                    .frame(width: markerSize, height: markerSize)
                    .overlay(Circle().strokeBorder(Color.liteAccent.opacity(0.3), lineWidth: 1))
            }
        }
        .font(.system(size: markerSize))
        .frame(width: markerSize + 2, height: markerSize + 2)
    }

    private func color(_ status: AdminWorkOrderStepStatus) -> Color {
        switch status {
        case .done: .green
        case .notDone: .orange
        case .unknown: .secondary
        }
    }
}
