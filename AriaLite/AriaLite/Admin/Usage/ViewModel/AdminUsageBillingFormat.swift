//
//  AdminUsageBillingFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Come i controlli di fatturazione scrivono gli istanti (il tetto parte da un istante UTC, non da un giorno) e gli
//  elenchi di ruoli. Estende il formato della pagina senza toccarlo: gli istanti si leggono sempre in UTC, mai nel fuso
//  del telefono.
//

import Foundation

nonisolated extension AdminUsageFormat {
    /// Il giorno UTC di un istante, `YYYY-MM-DD`.
    static func utcDay(of instant: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let c = calendar.dateComponents([.year, .month, .day], from: instant)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "Nov 3" / "3 nov": il giorno UTC di un istante.
    static func shortDay(of instant: Date, locale: Locale = .autoupdatingCurrent) -> String? {
        shortDay(utcDay(of: instant), locale: locale)
    }

    /// "Nov 3, 2026" / "3 nov 2026": il giorno UTC di un istante, con l'anno (lo storico del tetto).
    static func dayWithYear(of instant: Date, locale: Locale = .autoupdatingCurrent) -> String? {
        dayWithYear(utcDay(of: instant), locale: locale)
    }

    /// Un elenco a parole nella lingua di chi legge ("owners and members"); un solo elemento resta com'è.
    static func list(_ items: [String], locale: Locale = .autoupdatingCurrent) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: items) ?? items.joined(separator: ", ")
    }

    /// La prima lettera maiuscola, nella lingua di chi legge.
    static func capitalized(_ text: String, locale: Locale = .autoupdatingCurrent) -> String {
        text.prefix(1).uppercased(with: locale) + text.dropFirst()
    }
}
