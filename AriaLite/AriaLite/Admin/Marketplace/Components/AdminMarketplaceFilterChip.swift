//
//  AdminMarketplaceFilterChip.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il chip del Marketplace: un tipo col suo conteggio ("Skill 14", evidenziato se scelto) oppure un filtro
//  attivo con la x per toglierlo. Solo l'aspetto: il tocco lo gestisce chi lo usa.
//

import SwiftUI

struct AdminMarketplaceFilterChip: View {
    let title: String
    /// Il numero accanto al titolo (selettore di tipo); nil per un filtro attivo.
    var count: Int?
    var isSelected = false
    /// Mostra la x: il chip è un filtro attivo da togliere.
    var isRemovable = false

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: title)
                .fontWeight(.semibold)
            if let count {
                Text(verbatim: String(count))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.liteAccent : Color.secondary)
            }
            if isRemovable {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
        .foregroundStyle(isSelected ? Color.liteAccent : Color.primary)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .ariaGlass(in: Capsule(), tint: isSelected ? Color.liteAccent.opacity(0.14) : nil)
        .contentShape(Capsule())
    }
}
