//
//  AdminScenarioRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di uno scenario nella lista: tipo, titolo, codice allarme, sessioni e affidabilità, la barra
//  degli esiti e una riga di dettagli in testo semplice (ultimo esito con il suo pallino, tendenza, maturità).
//

import SwiftUI

struct AdminScenarioRow: View {
    let scenario: AdminScenario

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: AdminScenarioKind.systemImage(for: scenario.kind))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: iconSize, height: iconSize)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let code = scenario.rowCode {
                        Text(code)
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Text(scenario.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Text("\(scenario.sessions) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AdminScenarioFormat.percent(scenario.metrics?.reliability))
                        .font(.headline.weight(.semibold).monospacedDigit())
                    Text("reliable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            AdminScenarioOutcomeBar(resolved: scenario.successCount ?? 0, unresolved: scenario.failureCount ?? 0,
                                    unclear: scenario.unclearCount ?? 0)
            if !scenario.rowDetails.isEmpty { details }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private var details: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if scenario.lastVerdict != nil {
                Circle()
                    .fill(scenario.lastVerdictTone.color)
                    .frame(width: 6, height: 6)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            }
            Text(scenario.rowDetails)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
