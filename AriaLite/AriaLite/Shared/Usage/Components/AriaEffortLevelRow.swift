//
//  AriaEffortLevelRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una riga del foglio "Effort": nome, moltiplicatore, badge "High use", costo per risposta e spunta sul livello
//  in uso. Un livello che il piano non offre è grigio, col lucchetto e il piano che lo sblocca: resta
//  raggiungibile da VoiceOver (che ne legge il motivo) ma toccarlo non cambia niente.
//

import SwiftUI

struct AriaEffortLevelRow: View {
    let row: AriaEffortPickerViewModel.Row
    let lockedHint: String
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var checkWidth: CGFloat = 20

    var body: some View {
        Button(action: action) { content }
            .buttonStyle(.plain)
            // Non è `disabled`: così VoiceOver lo raggiunge e ne legge il motivo.
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(row.isCurrent ? .isSelected : [])
            .accessibilityHint(row.isLocked ? lockedHint : "")
            .accessibilityIdentifier("effort.row.\(row.level.rawValue)")
    }

    private var content: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(row.isLocked ? Color.secondary : Color.liteAccent)
                .opacity(row.isCurrent ? 1 : 0)
                .frame(width: checkWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                titleLine
                subline
            }
            Spacer(minLength: 8)
            if !dynamicTypeSize.isAccessibilitySize, let multiplier = row.multiplier {
                multiplierText(multiplier)
            }
        }
        .foregroundStyle(row.isLocked ? Color.secondary : Color.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Nome e badge sulla stessa riga; con testo molto grande uno sotto l'altro (e il moltiplicatore con loro).
    private var titleLine: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(verbatim: row.name).font(.body.weight(.medium))
            if dynamicTypeSize.isAccessibilitySize, let multiplier = row.multiplier {
                multiplierText(multiplier)
            }
            if row.showsWarning { highUseBadge }
        }
    }

    @ViewBuilder
    private var subline: some View {
        if row.isLocked {
            if let reason = row.lockReason {
                Label {
                    Text(verbatim: reason)
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        } else if let cost = row.costLine {
            Text(verbatim: cost)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func multiplierText(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    /// Ambra, mai rosso: costa di più, non è un errore.
    private var highUseBadge: some View {
        Label("High use", systemImage: "exclamationmark.triangle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.liteWarning)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.liteWarning.opacity(0.14), in: Capsule())
    }
}
