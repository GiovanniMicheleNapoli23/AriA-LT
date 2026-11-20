//
//  AdminConnectorStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un connettore (o della connessione di un membro) come pastiglia colorata con icona. Nelle schede
//  della griglia (`fitsWidth`), se il testo non ci sta resta solo l'icona: la scheda non esce dalla sua colonna.
//

import SwiftUI

struct AdminConnectorStatusBadge: View {
    let status: String
    /// Nella griglia: senza spazio per il testo, solo l'icona (con il testo per VoiceOver).
    var fitsWidth = false

    var body: some View {
        if fitsWidth {
            ViewThatFits(in: .horizontal) {
                pill(showsTitle: true)
                pill(showsTitle: false)
            }
        } else {
            pill(showsTitle: true)
        }
    }

    private func pill(showsTitle: Bool) -> some View {
        let known = AdminConnectorStatus(raw: status)
        let title = AdminConnectorStatus.label(for: status)
        return Label(title, systemImage: known.systemImage)
            .labelStyle(BadgeLabelStyle(showsTitle: showsTitle))
            .font(.caption2.weight(.bold))
            .foregroundStyle(known.tint)
            .padding(.horizontal, showsTitle ? 8 : 5)
            .padding(.vertical, 3)
            .background(known.tint.opacity(0.14), in: Capsule())
            .fixedSize()
            .accessibilityLabel(title)
    }
}

private struct BadgeLabelStyle: LabelStyle {
    let showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        if showsTitle {
            Label(configuration)
        } else {
            configuration.icon
        }
    }
}
