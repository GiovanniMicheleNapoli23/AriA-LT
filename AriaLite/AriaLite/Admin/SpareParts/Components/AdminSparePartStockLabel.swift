//
//  AdminSparePartStockLabel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Quantità a magazzino contro la scorta minima ("4 pcs · min 10"), in rosso quando è sotto scorta.
//  Un articolo non a magazzino lo dice al posto dei numeri.
//

import SwiftUI

struct AdminSparePartStockLabel: View {
    let part: AdminSparePart

    var body: some View {
        if part.nonStock {
            Label("Non-stock", systemImage: "cart")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 4) {
                Image(systemName: part.isLowStock ? "exclamationmark.triangle.fill" : "shippingbox")
                Text(verbatim: part.quantityText(part.stockQuantity))
                    .monospacedDigit()
                if let minimum = part.minQuantity {
                    Text("· min \(minimum)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(part.isLowStock ? Color.red : Color.primary)
        }
    }
}
