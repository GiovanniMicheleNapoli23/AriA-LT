//
//  AdminVendorTypeBadge.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il tipo di fornitore come capsula (testo libero, mostrato com'è).
//

import SwiftUI

struct AdminVendorTypeBadge: View {
    let label: String

    var body: some View {
        Text(verbatim: label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.liteAccent)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.liteAccent.opacity(0.1), in: Capsule())
    }
}
