//
//  AdminCraftedMonthHeader.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  L'intestazione di un mese nella lista di Crafted.
//

import SwiftUI

struct AdminCraftedMonthHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
