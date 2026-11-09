//
//  AdminPurchaseOrderDayText.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I giorni degli ordini ("YYYY-MM-DD") senza sorprese di fuso orario: il server li manda come giorno a
//  mezzanotte UTC, il selettore data del telefono lavora in fuso locale. Qui si passa dall'uno all'altro
//  tenendo fermo il giorno di calendario, e si scrive il giorno per l'utente.
//

import Foundation

nonisolated enum AdminPurchaseOrderDayText {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private static func dayString(_ components: DateComponents) -> String {
        String(format: "%04ld-%02ld-%02ld", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }

    /// Il giorno scelto nel selettore (fuso locale) come "YYYY-MM-DD", pronto da mandare al server.
    static func string(fromLocal date: Date, calendar: Calendar = .current) -> String {
        dayString(calendar.dateComponents([.year, .month, .day], from: date))
    }

    /// Il giorno di un valore del server come "YYYY-MM-DD"; `nil` se manca o non si legge.
    static func string(fromRaw raw: String?) -> String? {
        guard let date = AdminPurchaseOrderDates.parse(raw) else { return nil }
        return dayString(utcCalendar.dateComponents([.year, .month, .day], from: date))
    }

    /// Lo stesso giorno di calendario a mezzanotte locale, per il selettore data.
    static func localDate(fromRaw raw: String?, calendar: Calendar = .current) -> Date? {
        guard let date = AdminPurchaseOrderDates.parse(raw) else { return nil }
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: components)
    }

    /// "12 Oct 2026" nella lingua del telefono, senza spostare il giorno.
    static func display(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
    }
}
