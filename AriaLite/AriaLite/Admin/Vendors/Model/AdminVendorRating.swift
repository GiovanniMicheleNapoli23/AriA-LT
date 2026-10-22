//
//  AdminVendorRating.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il rating di un fornitore. L'OpenAPI dice solo "number": si assume la scala 0…5 della web, a mezzi
//  punti. Un valore fuori scala si riporta dentro (mostrato e confrontato), non si scarta.
//

import Foundation

nonisolated enum AdminVendorRating {
    static let range = 0.0...5.0
    static let step = 0.5

    static func clamp(_ value: Double) -> Double { min(max(value, range.lowerBound), range.upperBound) }

    /// Al mezzo punto più vicino, dentro la scala.
    static func snapped(_ value: Double) -> Double { clamp((value / step).rounded() * step) }

    /// "4.5", "3": senza decimali inutili.
    static func text(_ value: Double) -> String {
        clamp(value).formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Le cinque stelle di un valore: piena, mezza, vuota.
    static func symbols(for value: Double) -> [String] {
        let halves = Int((snapped(value) * 2).rounded())
        return (0..<5).map { index in
            if halves >= (index + 1) * 2 { "star.fill" } else if halves == index * 2 + 1 { "star.leadinghalf.filled" } else { "star" }
        }
    }
}
