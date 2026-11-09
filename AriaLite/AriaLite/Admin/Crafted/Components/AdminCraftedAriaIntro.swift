//
//  AdminCraftedAriaIntro.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  In cima al pannello di Aria, prima della prima richiesta: la sfera, la domanda e cosa succede dopo —
//  le modifiche si vedono sulla pagina e non si salva niente finché non si accettano.
//

import SwiftUI

struct AdminCraftedAriaIntro: View {
    @ScaledMetric(relativeTo: .title2) private var orbSide: CGFloat = 44

    var body: some View {
        HStack(spacing: 12) {
            AriaOrb(isAnimating: false).frame(width: orbSide, height: orbSide)
            VStack(alignment: .leading, spacing: 2) {
                Text("What should Aria change?").font(.headline)
                Text("Changes appear on the page. Nothing is saved until you accept.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
