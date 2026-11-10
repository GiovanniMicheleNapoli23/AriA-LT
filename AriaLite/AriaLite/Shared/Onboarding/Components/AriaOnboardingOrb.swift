//
//  AriaOnboardingOrb.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La sfera di Aria che accompagna tutta la presentazione: resta ferma mentre le pagine scorrono, col suo alone,
//  e il medaglione di vetro attaccato in basso a destra cambia simbolo con la pagina.
//

import SwiftUI

struct AriaOnboardingOrb: View {
    let side: CGFloat
    /// Il simbolo della pagina; nessuno nella scelta del ruolo.
    var symbol: String?

    var body: some View {
        AriaOrb(radius: 0.8)
            .frame(width: side, height: side)
            .background { AriaOrbGlow().scaleEffect(side / 220) }
            .shadow(color: Color.liteAccent.opacity(0.18), radius: side * 0.15, x: 0, y: side * 0.08)
            .overlay(alignment: .bottomTrailing) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.liteAccent)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: side * 0.4, height: side * 0.4)
                        .ariaGlass(in: Circle())
                        .offset(x: side * 0.08, y: side * 0.04)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: symbol)
            .accessibilityHidden(true)
    }
}
