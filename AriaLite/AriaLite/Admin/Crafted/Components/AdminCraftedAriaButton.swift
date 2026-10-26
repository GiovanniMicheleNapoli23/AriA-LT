//
//  AdminCraftedAriaButton.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  "Modifica con Aria" nei lettori di Crafted: il blob di Aria in un cerchio di vetro, in basso a destra,
//  come l'assistente nel dettaglio di un ordine. Più grande su iPad.
//

import SwiftUI

struct AdminCraftedAriaButton: View {
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .title) private var compactSize: CGFloat = 60

    private var size: CGFloat { sizeClass == .regular ? compactSize + 8 : compactSize }

    var body: some View {
        Button(action: action) {
            AriaOrb(isAnimating: false, radius: 0.86)
                .frame(width: size - 12, height: size - 12)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .ariaGlass(in: Circle(), interactive: true)
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .accessibilityLabel(Text("Edit with Aria"))
    }
}
