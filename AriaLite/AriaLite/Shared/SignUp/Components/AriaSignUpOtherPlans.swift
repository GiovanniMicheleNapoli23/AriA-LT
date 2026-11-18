//
//  AriaSignUpOtherPlans.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Other plans": una card con una riga per piano, nome e tagline a sinistra. I piani a pagamento dicono "Soon",
//  quelli a contratto "Contact" e aprono la mail alle vendite.
//

import SwiftUI

struct AriaSignUpOtherPlans: View {
    let title: String
    let rows: [AriaTrialOffer.PlanRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.liteText)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    if row.id != rows.first?.id { Divider().overlay(Color.liteBorder) }
                    planRow(row)
                }
            }
            .ariaSignUpCard()
        }
    }

    @ViewBuilder
    private func planRow(_ row: AriaTrialOffer.PlanRow) -> some View {
        switch row.kind {
        case .soon:
            content(row)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityLabel)
        case .contact(let url):
            Link(destination: url) { content(row) }
                .buttonStyle(.plain)
                .accessibilityLabel(row.accessibilityLabel)
        }
    }

    private func content(_ row: AriaTrialOffer.PlanRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.liteText)
                Text(row.tagline)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch row.kind {
            case .soon:
                Text(row.trailing)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .contact:
                HStack(spacing: 4) {
                    Text(row.trailing)
                    Image(systemName: "arrow.up.right")
                        .imageScale(.small)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.liteAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
