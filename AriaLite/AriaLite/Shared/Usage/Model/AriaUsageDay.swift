//
//  AriaUsageDay.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I giorni dei crediti sono giorni UTC (`start`, `end`, `last_days[].day`) e gli istanti di reset sono UTC: si
//  leggono e si scrivono in UTC, mai nel fuso del telefono, che sposterebbe il giorno. Come shortDate della web.
//

import Foundation

nonisolated enum AriaUsageDay {
    private static let utc = TimeZone(secondsFromGMT: 0)!

    /// Mezzanotte UTC di un giorno `YYYY-MM-DD`; un istante completo ("…T00:00:00Z") si legge com'è. `nil` se illeggibile.
    static func date(_ isoDay: String) -> Date? {
        if isoDay.contains("T") { return AriaDate.parse(isoDay) }
        let parts = isoDay.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let components = DateComponents(calendar: calendar, timeZone: utc, year: year, month: month, day: day)
        // Un 31 febbraio o un mese 13 scivolerebbero sul giorno dopo: si scartano.
        guard let date = components.date else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        guard back.year == year, back.month == month, back.day == day else { return nil }
        return date
    }

    /// "Nov 16" / "16 nov" (in italiano il primo del mese è "1° dic").
    static func short(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        format(date, template: "dMMM", italianFirst: "d'°' MMM", locale: locale)
    }

    static func short(_ isoDay: String, locale: Locale = .autoupdatingCurrent) -> String? {
        date(isoDay).map { short($0, locale: locale) }
    }

    /// "December 1" / "1° dicembre".
    static func long(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        format(date, template: "dMMMM", italianFirst: "d'°' MMMM", locale: locale)
    }

    static func long(_ isoDay: String, locale: Locale = .autoupdatingCurrent) -> String? {
        date(isoDay).map { long($0, locale: locale) }
    }

    /// Il giorno della settimana abbreviato ("Wed"), per l'asse del grafico dei 7 giorni.
    static func weekday(_ isoDay: String, locale: Locale = .autoupdatingCurrent) -> String? {
        guard let date = date(isoDay) else { return nil }
        let formatter = makeFormatter(locale: locale)
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private static func format(_ date: Date, template: String, italianFirst: String, locale: Locale) -> String {
        let formatter = makeFormatter(locale: locale)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        if locale.language.languageCode?.identifier == "it", calendar.component(.day, from: date) == 1 {
            formatter.dateFormat = italianFirst
        } else {
            formatter.setLocalizedDateFormatFromTemplate(template)
        }
        return formatter.string(from: date)
    }

    private static func makeFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = utc
        return formatter
    }
}
