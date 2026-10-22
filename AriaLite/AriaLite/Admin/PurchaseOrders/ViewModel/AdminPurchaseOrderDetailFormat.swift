//
//  AdminPurchaseOrderDetailFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Formati e calcoli puri del dettaglio di un ordine: importi nella valuta del dispositivo, quantità, giorni
//  (le date "YYYY-MM-DD" sono giorni di calendario, non istanti: si leggono in UTC per non slittare di un giorno)
//  e il ritardo sulla consegna prevista.
//

import Foundation

nonisolated enum AdminPurchaseOrderDetailFormat {
    static var currencyCode: String { Locale.current.currency?.identifier ?? "EUR" }

    static func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    static func quantity(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)))
    }

    /// Un giorno ("YYYY-MM-DD") come data breve, senza ora e nello stesso giorno scritto dal server.
    static func day(raw: String?, value: Date?) -> String? {
        guard let value else { return nil }
        if isDayOnly(raw) {
            return value.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
        }
        return value.formatted(date: .abbreviated, time: .omitted)
    }

    static func dateTime(_ value: Date?) -> String? {
        value?.formatted(date: .abbreviated, time: .shortened)
    }

    /// La consegna prevista è già passata (giorno intero: oggi non è in ritardo).
    static func isPast(raw: String?, value: Date?, now: Date = .now) -> Bool {
        guard let value else { return false }
        let expected = dayKey(value, calendar: isDayOnly(raw) ? utcCalendar : .current)
        return expected < dayKey(now, calendar: .current)
    }

    /// Somma delle righe che hanno un totale; `nil` se nessuna lo ha.
    static func sum(of lines: [AdminPurchaseOrderLine]) -> Double? {
        let totals = lines.compactMap(\.lineTotal)
        return totals.isEmpty ? nil : totals.reduce(0, +)
    }

    private static func isDayOnly(_ raw: String?) -> Bool { raw?.count == 10 }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}
