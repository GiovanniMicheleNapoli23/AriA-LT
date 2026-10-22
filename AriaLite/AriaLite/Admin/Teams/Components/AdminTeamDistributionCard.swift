//
//  AdminTeamDistributionCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una distribuzione del carico come barre semplici: una riga per voce, la barra è in proporzione alla voce più
//  grande.
//

import SwiftUI

struct AdminTeamDistributionCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let rows: [AdminTeamDistributionRow]

    @ScaledMetric(relativeTo: .caption) private var barHeight = 8

    private var maximum: Int { max(rows.map(\.count).max() ?? 1, 1) }

    var body: some View {
        AdminCard(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(verbatim: row.label).font(.subheadline)
                            Spacer(minLength: 8)
                            Text(row.count, format: .number)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        Capsule()
                            .fill(.quaternary)
                            .frame(height: barHeight)
                            .overlay(alignment: .leading) {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(row.tint)
                                        .frame(width: proxy.size.width * Double(row.count) / Double(maximum))
                                }
                            }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
