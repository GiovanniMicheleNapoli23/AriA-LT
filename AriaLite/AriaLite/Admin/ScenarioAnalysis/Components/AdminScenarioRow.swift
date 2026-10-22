//
//  AdminScenarioRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda di uno scenario nella lista: tipo, titolo, codice allarme, sessioni, affidabilità,
//  tendenza e maturità, con la barra degli esiti.
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
                        .foregroundStyle(Color.liteAccent)
                        .frame(width: iconSize, height: iconSize)
                        .background(Color.liteAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let code = scenario.alarmCode {
                        Text(code)
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(Color.liteAccent)
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
                        .font(.headline.monospacedDigit())
                    Text("reliable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            AdminScenarioOutcomeBar(resolved: scenario.successCount ?? 0, unresolved: scenario.failureCount ?? 0,
                                    unclear: scenario.unclearCount ?? 0)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { badges }
                VStack(alignment: .leading, spacing: 6) { badges }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var badges: some View {
        if let trend = scenario.metrics?.trend {
            AdminScenarioBadge(text: AdminScenarioLabel.trend(trend), tone: AdminScenarioLabel.trendTone(trend),
                               systemImage: AdminScenarioLabel.trendSystemImage(trend))
        }
        if let maturity = scenario.metrics?.maturity {
            AdminScenarioBadge(text: AdminScenarioLabel.maturity(maturity), tone: AdminScenarioLabel.maturityTone(maturity))
        }
        if let verdict = scenario.lastVerdict {
            AdminScenarioBadge(text: String(localized: "Last: \(AdminScenarioLabel.verdict(verdict))"),
                               tone: AdminScenarioLabel.verdictTone(verdict))
        }
    }
}
