//
//  AdminUsageAmountInput.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Come si legge un numero scritto a mano nei controlli di fatturazione (limite di spesa, soglia degli avvisi): solo
//  cifre, al più due decimali, il punto o la virgola come separatore. Tutto il resto è non valido e non si manda.
//

import Foundation

nonisolated enum AdminUsageAmountInput {
    /// Cifre, poi al più due decimali dopo un punto o una virgola (`^\d+([.,]\d{1,2})?$`, cifre ASCII). `nil` se la forma non è questa.
    static func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var whole = ""
        var fraction = ""
        var seenSeparator = false
        for character in trimmed {
            switch character {
            case "0"..."9" where character.isASCII:
                if seenSeparator { fraction.append(character) } else { whole.append(character) }
            case "." where !seenSeparator, "," where !seenSeparator:
                seenSeparator = true
            default:
                return nil
            }
        }
        guard !whole.isEmpty else { return nil }
        if seenSeparator, fraction.isEmpty || fraction.count > 2 { return nil }
        return AriaDecimal.parse(seenSeparator ? "\(whole).\(fraction)" : whole)
    }
}
