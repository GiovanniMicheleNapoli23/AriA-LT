//
//  AdminScenarioOutcomeBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una barra sottile divisa fra sessioni risolte, non risolte e incerte di uno scenario, nei toni spenti
//  della sezione su un binario appena visibile.
//

import SwiftUI

struct AdminScenarioOutcomeBar: View {
    let resolved: Int
    let unresolved: Int
    let unclear: Int

    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 4

    private var total: Int { resolved + unresolved + unclear }

    var body: some View {
        if total > 0 {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    segment(resolved, AdminScenarioTone.positive.color, width: proxy.size.width)
                    segment(unresolved, AdminScenarioTone.negative.color.opacity(0.85), width: proxy.size.width)
                    segment(unclear, Color.secondary.opacity(0.35), width: proxy.size.width)
                }
            }
            .frame(height: height)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .clipShape(Capsule())
            .accessibilityElement()
            .accessibilityLabel(Text("\(resolved) resolved, \(unresolved) unresolved, \(unclear) unclear"))
        }
    }

    @ViewBuilder
    private func segment(_ count: Int, _ color: Color, width: CGFloat) -> some View {
        if count > 0 {
            Capsule()
                .fill(color)
                .frame(width: max(height, (width - 4) * CGFloat(count) / CGFloat(total)))
        }
    }
}
