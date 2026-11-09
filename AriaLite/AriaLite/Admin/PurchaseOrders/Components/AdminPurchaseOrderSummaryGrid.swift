//
//  AdminPurchaseOrderSummaryGrid.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il riepilogo sopra la lista: caselle con numero e titolo che si dispongono in base alla larghezza
//  (due colonne su iPhone, di più su iPad), senza scorrimento orizzontale.
//

import SwiftUI

struct AdminPurchaseOrderSummaryGrid: View {
    let tiles: [AdminPurchaseOrderSummaryTile]

    @ScaledMetric(relativeTo: .caption) private var iconSize = 18.0

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)], spacing: 10) {
            ForEach(tiles) { tile in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tile.systemImage)
                        .font(.subheadline)
                        .foregroundStyle(tile.tint)
                        .frame(width: iconSize, height: iconSize)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: tile.value)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(verbatim: tile.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ariaGlass(in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
            }
        }
    }
}
