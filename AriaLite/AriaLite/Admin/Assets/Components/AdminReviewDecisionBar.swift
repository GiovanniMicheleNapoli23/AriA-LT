//
//  AdminReviewDecisionBar.swift
//  AriaLite
//
//  Created by Giovanni Michele on 11/11/26.
//
//  Le decisioni di revisione di un asset, un allarme, un ricambio o un piano, fisse in basso come nel dettaglio
//  di un'estrazione: capsule che galleggiano da sole. Approve è piena nel colore dell'app e prende il resto della
//  riga, Reject è di vetro in rosso, Unapprove e Back to draft di vetro neutre. Con il testo grande una sotto
//  l'altra, la principale sopra. Sopra i pulsanti, l'ultimo errore.
//

import SwiftUI

struct AdminReviewDecisionBar: View {
    let actions: [AdminReviewAction]
    /// La decisione in corso, se c'è: la sua capsula gira, tutte sono ferme.
    var running: AdminReviewAction?
    var error: String?
    let perform: (AdminReviewAction) -> Void

    /// Senza una principale (un approvato: Reject e Unapprove) le capsule si dividono la riga.
    private var hasPrimary: Bool { actions.contains { $0.isPrimary } }

    var body: some View {
        VStack(spacing: 8) {
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.liteDanger)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .ariaGlass(in: Capsule())
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    ForEach(actions, id: \.self) { button($0, fills: $0.isPrimary || !hasPrimary) }
                }
                VStack(spacing: 10) {
                    ForEach(actions.reversed(), id: \.self) { button($0, fills: true) }
                }
            }
            .disabled(running != nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .ariaReadableWidth()
    }

    @ViewBuilder
    private func button(_ action: AdminReviewAction, fills: Bool) -> some View {
        let button = Button { perform(action) } label: { label(action, fills: fills) }
        if action.isPrimary {
            button.ariaAccentGlassButtonStyle().buttonBorderShape(.capsule)
        } else {
            button.ariaGlassButtonStyle().buttonBorderShape(.capsule)
        }
    }

    private func label(_ action: AdminReviewAction, fills: Bool) -> some View {
        HStack(spacing: 6) {
            if running == action {
                ProgressView().tint(foreground(action))
            } else {
                Image(systemName: action.systemImage)
                Text(action.title)
            }
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(foreground(action))
        .padding(.horizontal, 14)
        .frame(maxWidth: fills ? .infinity : nil, minHeight: 50)
    }

    private func foreground(_ action: AdminReviewAction) -> Color {
        switch action {
        case .approve: .liteOnAccent
        case .reject: .liteDanger
        case .unapprove, .backToDraft: .primary
        }
    }
}
