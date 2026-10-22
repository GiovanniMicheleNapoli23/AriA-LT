//
//  AdminWorkOrderAssistantButton.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il pulsante flottante dell'assistente nel dettaglio di un ordine: il blob di Aria in un cerchio di
//  vetro, in basso a destra. Più grande su iPad.
//

import SwiftUI

struct AdminWorkOrderAssistantButton: View {
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .title) private var compactSize: CGFloat = 60

    private var size: CGFloat { sizeClass == .regular ? compactSize + 8 : compactSize }

    var body: some View {
        Button(action: action) {
            AriaOrb(radius: 0.86)
                .frame(width: size - 12, height: size - 12)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .ariaGlass(in: Circle(), interactive: true)
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .accessibilityLabel(Text("AI assistant"))
    }
}
