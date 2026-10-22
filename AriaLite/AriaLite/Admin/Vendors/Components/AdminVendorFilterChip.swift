//
//  AdminVendorFilterChip.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Capsula di un filtro per tipo: piena (accento) quando è attiva, di vetro quando no.
//

import SwiftUI

struct AdminVendorFilterChip: View {
    let title: String
    var count: Int?
    var isSelected = false

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: title)
            if let count {
                Text(verbatim: "\(count)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .opacity(0.7)
            }
        }
        .font(.footnote.weight(.semibold))
        .lineLimit(1)
        .foregroundStyle(isSelected ? Color.liteOnAccent : Color.liteAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if isSelected { Capsule().fill(Color.liteAccent) }
        }
        .ariaGlass(in: Capsule())
        .contentShape(Capsule())
    }
}
