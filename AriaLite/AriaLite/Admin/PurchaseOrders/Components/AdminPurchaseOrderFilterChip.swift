//
//  AdminPurchaseOrderFilterChip.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Capsula di un filtro: piena (accento) quando è attivo, di vetro quando no. Fa da etichetta a un menu
//  (stato, fornitore) o a un pulsante (Cancella).
//

import SwiftUI

struct AdminPurchaseOrderFilterChip: View {
    let title: String
    var systemImage: String?
    var isSelected = false
    var tint = Color.liteAccent
    /// Freccia in giù: il chip apre un menu.
    var showsMenuIndicator = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(verbatim: title)
            if showsMenuIndicator {
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
        }
        .font(.footnote.weight(.semibold))
        .lineLimit(1)
        .foregroundStyle(isSelected ? Color.liteOnAccent : tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if isSelected { Capsule().fill(tint) }
        }
        .ariaGlass(in: Capsule())
        .contentShape(Capsule())
    }
}
