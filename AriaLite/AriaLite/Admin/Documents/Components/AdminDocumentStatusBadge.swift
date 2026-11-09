//
//  AdminDocumentStatusBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La pillola con lo stato complessivo di un documento (in elaborazione, pronto, fallito…).
//

import SwiftUI

struct AdminDocumentStatusBadge: View {
    let group: AdminDocumentStatusGroup

    var body: some View {
        // Icona e testo a mano, non un Label: dentro una List prenderebbe lo stile della riga (solo icona, alto).
        HStack(spacing: 4) {
            Image(systemName: group.systemImage)
            Text(group.label)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(group.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(group.tint.opacity(0.14), in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}
