//
//  AdminUsageSpendCapTrialView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda del limite durante la prova gratuita: €0, il chip "Free trial", la frase e "Choose a plan". Nessun campo e
//  nessun bottone per salvare.
//

import SwiftUI

struct AdminUsageSpendCapTrialView: View {
    let trial: AdminUsageSpendCapCard.Trial

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdminUsageSpendCapFigure(amount: trial.amount, credits: nil, chip: trial.chip, isReached: false, subline: trial.since)
            Text(verbatim: trial.body)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let choose = trial.choosePlan {
                Button { openURL(choose.url) } label: { Text(verbatim: choose.label) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.liteAccent)
                    .foregroundStyle(Color.liteOnAccent)
            }
        }
    }
}

/// La cifra del limite, i crediti che compra e il chip di stato, con la riga "per cycle · since…" sotto.
struct AdminUsageSpendCapFigure: View {
    let amount: String
    let credits: String?
    let chip: String
    let isReached: Bool
    let subline: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: amount).font(.title2.weight(.semibold).monospacedDigit())
                AdminUsageBillingChip(text: chip, tone: isReached ? .over : .normal)
            }
            if let credits {
                Text(verbatim: credits).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let subline {
                Text(verbatim: subline).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
