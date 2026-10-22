//
//  AdminFilterChip.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'etichetta di un filtro della lista (nome e valore scelto): evidenziata quando filtra davvero.
//  Il menu con le scelte lo mette chi la usa.
//

import SwiftUI

struct AdminFilterChip: View {
    let title: LocalizedStringKey
    let value: String
    var isActive = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            Text(value).fontWeight(.semibold)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .foregroundStyle(isActive ? Color.liteAccent : Color.primary)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .ariaGlass(in: Capsule(), tint: isActive ? Color.liteAccent.opacity(0.12) : nil)
        .contentShape(Capsule())
    }
}
