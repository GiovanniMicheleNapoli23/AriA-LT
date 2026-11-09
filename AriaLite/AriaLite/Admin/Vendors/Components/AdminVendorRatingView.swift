//
//  AdminVendorRatingView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il rating di un fornitore: cinque stelle (anche mezze) e il numero. Senza rating non si disegna.
//

import SwiftUI

struct AdminVendorRatingView: View {
    let value: Double
    /// Solo "★ 4.5", per le righe strette.
    var isCompact = false

    var body: some View {
        HStack(spacing: 4) {
            if isCompact {
                Image(systemName: "star.fill").foregroundStyle(.orange)
            } else {
                HStack(spacing: 2) {
                    ForEach(Array(AdminVendorRating.symbols(for: value).enumerated()), id: \.offset) { _, symbol in
                        Image(systemName: symbol)
                    }
                }
                .foregroundStyle(.orange)
            }
            Text(verbatim: AdminVendorRating.text(value))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.footnote)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rating"))
        .accessibilityValue(Text("\(AdminVendorRating.text(value)) out of 5"))
    }
}
