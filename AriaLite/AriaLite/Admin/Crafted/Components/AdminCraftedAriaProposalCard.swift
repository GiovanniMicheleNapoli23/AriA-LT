//
//  AdminCraftedAriaProposalCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La proposta di Aria sulla pagina: di quanto cambia il documento, la legenda dei colori, e Accetta
//  (la versione nuova), Scarta e "Apri la conversazione" — dove si risponde a "perché l'ha cambiato".
//

import SwiftUI

struct AdminCraftedAriaProposalCard: View {
    let summary: AdminCraftedAriaProposalSummary
    let actions: AdminCraftedAriaActions

    @ScaledMetric(relativeTo: .subheadline) private var orbSide: CGFloat = 18

    var body: some View {
        AriaCard {
            HStack(spacing: 8) {
                AriaOrb(isAnimating: false).frame(width: orbSide, height: orbSide)
                Text("Proposal on the page")
            }
            .font(.subheadline.weight(.semibold))
            Text(summary.changes).font(.footnote).foregroundStyle(.secondary)
            AdminCraftedDiffLegend()
            Button(action: actions.accept) {
                Text(summary.acceptTitle).frame(maxWidth: .infinity)
            }
            .ariaAccentGlassButtonStyle()
            Button(role: .destructive, action: actions.discard) {
                Text("Discard").frame(maxWidth: .infinity)
            }
            .ariaGlassButtonStyle()
            Button(action: actions.openChat) {
                Label("Open the conversation", systemImage: "bubble.left.and.text.bubble.right")
                    .frame(maxWidth: .infinity)
            }
            .ariaGlassButtonStyle()
        }
    }
}
