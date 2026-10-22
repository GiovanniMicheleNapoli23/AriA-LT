//
//  AdminScenarioOutcomeBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una barra sottile divisa fra sessioni risolte, non risolte e incerte di uno scenario.
//

import SwiftUI

struct AdminScenarioOutcomeBar: View {
    let resolved: Int
    let unresolved: Int
    let unclear: Int

    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 6

    private var total: Int { resolved + unresolved + unclear }

    var body: some View {
        if total > 0 {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    segment(resolved, .green, width: proxy.size.width)
                    segment(unresolved, .red, width: proxy.size.width)
                    segment(unclear, Color.secondary.opacity(0.5), width: proxy.size.width)
                }
            }
            .frame(height: height)
            .clipShape(Capsule())
            .accessibilityElement()
            .accessibilityLabel(Text("\(resolved) resolved, \(unresolved) unresolved, \(unclear) unclear"))
        }
    }

    @ViewBuilder
    private func segment(_ count: Int, _ color: Color, width: CGFloat) -> some View {
        if count > 0 {
            color.frame(width: max(2, (width - 4) * CGFloat(count) / CGFloat(total)))
        }
    }
}
