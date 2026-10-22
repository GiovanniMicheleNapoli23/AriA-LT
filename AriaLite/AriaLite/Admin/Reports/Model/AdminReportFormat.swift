//
//  AdminReportFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Piccole funzioni per leggere e mostrare i numeri dei report: il server manda conteggi come interi o
//  decimali, a volte dentro un oggetto, e le chiavi (`in_progress`) vanno rese leggibili.
//

import Foundation

nonisolated enum AdminReportFormat {
    /// Chiavi che possono contenere il numero quando il valore è un oggetto.
    static let countKeys = ["count", "total", "value", "n", "failures", "failure_count", "wo_count",
                            "work_orders", "completed"]

    /// Il numero di un valore libero: numero, testo numerico o oggetto con un campo conteggio.
    static func number(_ json: AriaJSON?) -> Double? {
        switch json {
        case .number(let value)?: return value
        case .string?: return json?.doubleValue
        case .object(let object)?:
            for key in countKeys { if let value = number(object[key]) { return value } }
            return nil
        default: return nil
        }
    }

    /// Il primo testo non vuoto fra le chiavi date.
    static func text(_ object: [String: AriaJSON], keys: [String]) -> String? {
        for key in keys { if let value = object[key]?.nonEmptyString { return value } }
        return nil
    }

    /// `in_progress` → "In progress". Le chiavi già leggibili (maiuscole, spazi) restano com'erano.
    static func humanized(_ key: String) -> String {
        let spaced = key.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        let trimmed = spaced.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, trimmed == trimmed.lowercased() else { return trimmed.isEmpty ? key : trimmed }
        return first.uppercased() + trimmed.dropFirst()
    }

    /// Interi senza decimali, il resto con al massimo uno.
    static func count(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
