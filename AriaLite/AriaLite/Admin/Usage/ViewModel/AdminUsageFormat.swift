//
//  AdminUsageFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Come la pagina Usage scrive cifre, importi e percentuali (contratto 3.1, "How the web writes figures"). Funzioni
//  pure e generali: le riusano anche i controlli di fatturazione. Nessuna cifra nasce qui, si formatta solo quella
//  del server. Ogni funzione prende la lingua (`locale`): di default quella del telefono.
//

import Foundation

nonisolated enum AdminUsageFormat {
    // MARK: Crediti e numeri

    /// Crediti con al più un decimale e le migliaia nella lingua di chi legge: 1700 → "1,700", 38.4 → "38.4".
    /// L'arrotondamento è "mezzo verso l'alto" come `Intl` della web, non quello pari di ICU.
    static func credits(_ value: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        AriaCredits.oneDecimal(value).formatted(Decimal.FormatStyle(locale: locale).precision(.fractionLength(0...1)))
    }

    /// Un numero intero (conteggio, minuti, percentuale), con le migliaia: 1628 → "1,628".
    static func whole(_ value: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        AriaCredits.wholeNumber(value).formatted(Decimal.FormatStyle(locale: locale).precision(.fractionLength(0)))
    }

    static func whole(_ value: Int, locale: Locale = .autoupdatingCurrent) -> String {
        whole(Decimal(value), locale: locale)
    }

    /// Una quota del periodo (0.73) come percentuale intera: 73.
    static func percent(_ share: Decimal) -> Int {
        AriaCredits.percent(share)
    }

    /// Una soglia come cifra di percentuale per un campo di testo: senza migliaia e con al più due decimali
    /// (0.7 → "70", 0.625 → "62.5").
    static func thresholdPercent(_ share: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        rounded(share * 100, scale: 2).formatted(
            Decimal.FormatStyle(locale: locale).grouping(.never).precision(.fractionLength(0...2)))
    }

    // MARK: Importi

    /// Un prezzo o un tetto: intero senza centesimi (€500, €0), altrimenti con i decimali (€0.16).
    static func money(_ value: Decimal, currency: String, locale: Locale = .autoupdatingCurrent) -> String {
        AriaCredits.formatMoney(value, currency: currency, locale: locale)
    }

    /// Un importo addebitato o proiettato: sempre due decimali (€181.97, €28.00).
    static func amount(_ value: Decimal, currency: String, locale: Locale = .autoupdatingCurrent) -> String {
        rounded(value, scale: 2).formatted(
            Decimal.FormatStyle.Currency(code: currency, locale: locale).precision(.fractionLength(2)))
    }

    // MARK: Byte

    /// Come si arrotonda un archivio: al più vicino (usato, totale), per difetto (quanto resta: mai più di quello che
    /// c'è) o per eccesso (quanto è oltre: mai meno di quello che è).
    nonisolated enum StorageRounding: Sendable { case nearest, down, up }

    /// I byte in GB (÷ 1 000 000 000) con un decimale al più: 2.1e9 → "2.1 GB". Per "resta" e "oltre" sotto 0.1 GB
    /// si scrivono i centesimi, così una cifra diversa da zero non diventa "0 GB".
    static func gigabytes(_ bytes: Int, rounding: StorageRounding = .nearest, locale: Locale = .autoupdatingCurrent) -> String {
        let count = Decimal(max(0, bytes))
        let gb: Decimal
        let digits: ClosedRange<Int>
        switch rounding {
        case .nearest:
            gb = rounded(count / 1_000_000_000, scale: 1)
            digits = 0...1
        case .down, .up:
            let fine = count < 100_000_000
            let scale = fine ? 2 : 1
            gb = rounded(count / 1_000_000_000, scale: scale, mode: rounding == .down ? .down : .up)
            digits = 0...scale
        }
        let figure = gb.formatted(Decimal.FormatStyle(locale: locale).precision(.fractionLength(digits)))
        return String(localized: "\(figure) GB")
    }

    // MARK: Giorni UTC

    /// Un giorno `YYYY-MM-DD` (o un istante che comincia così) come mezzanotte UTC. Mai nel fuso del telefono.
    static func date(fromDay day: String) -> Date? {
        let parts = day.prefix(10).split(separator: "-", omittingEmptySubsequences: false).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(calendar: utcCalendar, year: parts[0], month: parts[1], day: parts[2]).date
    }

    /// Il giorno dopo un giorno `YYYY-MM-DD`: quando un ciclo si azzera.
    static func nextDay(_ day: String) -> String? {
        guard let start = date(fromDay: day), let next = utcCalendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return dayString(next)
    }

    /// I giorni interi da `from` a `to` (estremi come giorni UTC); negativo se `to` è prima.
    static func days(from: String, to: String) -> Int? {
        guard let a = date(fromDay: from), let b = date(fromDay: to) else { return nil }
        return utcCalendar.dateComponents([.day], from: a, to: b).day
    }

    /// Tutti i giorni da `start` a `end` compresi, come `YYYY-MM-DD`.
    static func days(inCycleFrom start: String, to end: String) -> [String] {
        guard let first = date(fromDay: start), let last = date(fromDay: end), first <= last else { return [] }
        var result: [String] = []
        var current = first
        while current <= last, result.count < 400 {
            result.append(dayString(current))
            guard let next = utcCalendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    /// "Nov 18" / "18 nov" / "1° dic": mese e giorno, in UTC. Il primo del mese in italiano è "1°".
    static func shortDay(_ day: String, locale: Locale = .autoupdatingCurrent) -> String? {
        guard let date = date(fromDay: day) else { return nil }
        let text = format(date, template: "MMMd", locale: locale)
        guard isItalian(locale), utcCalendar.component(.day, from: date) == 1 else { return text }
        return text.replacingOccurrences(of: #"(?<!\d)1(?!\d)"#, with: "1°", options: .regularExpression)
    }

    /// "Nov 9, 2026" / "9 nov 2026": un giorno con l'anno, come lo storico del tetto.
    static func dayWithYear(_ day: String, locale: Locale = .autoupdatingCurrent) -> String? {
        date(fromDay: day).map { format($0, template: "MMMdy", locale: locale) }
    }

    /// "November 2026" / "novembre 2026": il mese di un giorno.
    static func monthYear(_ day: String, locale: Locale = .autoupdatingCurrent) -> String? {
        date(fromDay: day).map { format($0, template: "MMMMy", locale: locale) }
    }

    /// "Mon, Nov 23" / "lun 23 nov": il giorno in cui il contatore settimanale riparte, da un istante, letto in UTC.
    static func weekDay(_ instant: Date, locale: Locale = .autoupdatingCurrent) -> String {
        format(instant, template: "EEEMMMd", locale: locale)
    }

    // MARK: Italiano

    /// L'italiano elide l'articolo davanti a 8x, 11 e 18 per cento ("l'82%", "all'83%"): `Intl` non lo fa, quindi
    /// la web lo corregge dopo. Le altre lingue passano senza cambiare.
    static func elide(_ text: String, locale: Locale = .autoupdatingCurrent) -> String {
        guard isItalian(locale),
              let regex = try? NSRegularExpression(pattern: #"\b(il|al|del|dal|nel|sul|Il|Al|Del|Dal|Nel|Sul) (8\d|11|18)(?=%)"#)
        else { return text }
        let elided = ["il": "l'", "al": "all'", "del": "dell'", "dal": "dall'", "nel": "nell'", "sul": "sull'"]
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let whole = Range(match.range, in: result), let article = Range(match.range(at: 1), in: text),
                  let number = Range(match.range(at: 2), in: text) else { continue }
            let word = String(text[article])
            guard var replacement = elided[word.lowercased()] else { continue }
            if word.first?.isUppercase == true { replacement = replacement.prefix(1).uppercased() + replacement.dropFirst() }
            result.replaceSubrange(whole, with: replacement + text[number])
        }
        return result
    }

    // MARK: Interno

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    private static func isItalian(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "it"
    }

    private static func dayString(_ date: Date) -> String {
        let c = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Un formattatore per lingua e formato, creato una volta sola (le etichette dei grafici ne chiedono decine).
    private static let formatters = AriaLocaleFormatterCache<DateFormatter>()

    private static func format(_ date: Date, template: String, locale: Locale) -> String {
        formatters.formatter(variant: template, locale: locale) {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            formatter.setLocalizedDateFormatFromTemplate(template)
            return formatter
        }.string(from: date)
    }

    private static func rounded(_ value: Decimal, scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }
}
