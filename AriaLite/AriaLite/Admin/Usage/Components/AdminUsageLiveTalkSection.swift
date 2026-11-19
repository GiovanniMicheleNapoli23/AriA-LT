//
//  AdminUsageLiveTalkSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Talk with Aria" (contratto 3.8): i minuti usati con la barra, "—" su un ciclo chiuso, oppure "Not in your
//  plan" col piano che lo include e, per un titolare, l'azione per scrivere alle vendite.
//

import SwiftUI

struct AdminUsageLiveTalkSection: View {
    let state: AdminUsageLiveTalkState
    let title: String

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .loading:
            AdminUsageCardFrame(title: Text(verbatim: title)) {
                AdminUsagePlaceholderLines(lines: 2)
            }
        case .ready(let card):
            AdminUsageCardFrame(title: Text(verbatim: card.title)) {
                VStack(alignment: .leading, spacing: 10) {
                    summary(card)
                    if let note = card.note { footnote(note) }
                    if let memberNote = card.memberNote { footnote(memberNote) }
                    if let action = card.action { actionLink(action) }
                }
            }
        }
    }

    @ViewBuilder
    private func summary(_ card: AdminUsageLiveTalkCard) -> some View {
        if let chip = card.lockedChip {
            Text(verbatim: chip)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
        if let value = card.value {
            Text(verbatim: value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
        }
        if let fraction = card.fraction {
            AriaCreditsMeter(fill: fraction, tick: nil, tint: Color.liteAccent)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func actionLink(_ action: AdminUsageMailAction) -> some View {
        Link(destination: action.url) {
            Text(verbatim: action.label)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .foregroundStyle(.primary)
    }
}
