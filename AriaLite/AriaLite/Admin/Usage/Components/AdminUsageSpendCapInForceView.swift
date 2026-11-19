//
//  AdminUsageSpendCapInForceView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Un limite in vigore (contratto 5.1): la cifra, da quando vale, quanto è usato con la barra, le frasi di "warned" e
//  "reached", e "Change" / "Remove limit". La barra è accento, ambra o grigio: mai rossa. Solo "Remove limit" è distruttivo.
//

import SwiftUI

struct AdminUsageSpendCapInForceView: View {
    let inForce: AdminUsageSpendCapCard.InForce
    let billing: AdminUsageBillingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdminUsageSpendCapFigure(amount: inForce.amount, credits: inForce.credits, chip: inForce.chip,
                                     isReached: inForce.isReached, subline: inForce.subline)
            if let used = inForce.used { usedView(used) }
            if let warned = inForce.warnedNote { AdminUsageBillingAlertBox(text: warned, kind: .warning) }
            if let reached = inForce.reachedNote {
                Text(verbatim: reached).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            if let always = inForce.alwaysOnNote {
                Text(verbatim: always).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let error = inForce.saveError { AdminUsageBillingAlertBox(text: error) }
            actions
        }
    }

    private func usedView(_ used: AdminUsageSpendCapCard.Used) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let fill = used.fill { AriaCreditsMeter(fill: fill, tick: nil, tint: used.tone.tint) }
            Text(verbatim: used.text).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { Spacer(minLength: 0); buttons }
            VStack(alignment: .leading, spacing: 8) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if inForce.canRemove {
            Button(inForce.removeLabel, role: .destructive) { billing.removeSpendCap() }
                .buttonStyle(.bordered)
                .disabled(billing.capSaving)
        }
        if inForce.changeIsProminent {
            Button(inForce.changeLabel) { billing.startEditing() }
                .buttonStyle(.borderedProminent)
                .tint(Color.liteAccent)
                .foregroundStyle(Color.liteOnAccent)
        } else {
            Button(inForce.changeLabel) { billing.startEditing() }
                .buttonStyle(.bordered)
                .tint(Color.liteAccent)
        }
    }
}
