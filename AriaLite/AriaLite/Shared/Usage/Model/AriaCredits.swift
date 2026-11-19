//
//  AriaCredits.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'aritmetica dei crediti e il loro formato. Solo `Decimal`, mai `Double`: 3.2 × 1 ÷ 0.1 deve fare esattamente 32,
//  così 3.2 resta 3.2 e non diventa 3.3. Nessuna cifra è scritta qui: pesi, moltiplicatori e passo vengono da
//  GET /v1/usage/config.
//

import Foundation

nonisolated enum AriaCredits {
    /// Il primo multiplo di `increment` che non è sotto `value`: ceil(value ÷ increment) × increment.
    /// Un passo nullo o negativo lascia il valore com'è.
    static func roundUp(_ value: Decimal, to increment: Decimal) -> Decimal {
        guard increment > 0 else { return value }
        var steps = value / increment
        var rounded = Decimal()
        NSDecimalRound(&rounded, &steps, 0, .up)
        return rounded * increment
    }

    /// I crediti di una risposta completata: peso dell'azione × moltiplicatore del livello, arrotondati per eccesso al
    /// passo di addebito. `nil` se il passo, il peso o il moltiplicatore mancano: nessuna cifra inventata.
    static func creditsPerReply(config: AriaUsageConfig, level: AriaEffortLevel,
                                action: String = "chat.reply") -> Decimal? {
        guard let increment = config.chargeRoundingIncrement, increment > 0,
              let weight = config.actions[action]?.creditWeight,
              let multiplier = config.effort?.levels[level]?.multiplier else { return nil }
        return roundUp(weight * multiplier, to: increment)
    }

    /// Quante risposte entrano in una giornata, per difetto. `nil` se manca una cifra o se non sono positive
    /// (un pool non dichiara un valore giornaliero).
    static func repliesPerDay(creditsPerDay: Decimal?, cost: Decimal?) -> Int? {
        guard let creditsPerDay, let cost, creditsPerDay > 0, cost > 0 else { return nil }
        return wholePart(creditsPerDay / cost)
    }

    /// Una cifra decimale per difetto: "disponibili" e "restanti" non promettono mai una frazione che non c'è.
    static func floorOneDecimal(_ value: Decimal) -> Decimal {
        rounded(value, scale: 1, mode: .down)
    }

    /// Una cifra decimale, come le schede stampano i crediti (62.6).
    static func oneDecimal(_ value: Decimal) -> Decimal {
        rounded(value, scale: 1, mode: .plain)
    }

    /// Un numero intero, al più vicino.
    static func wholeNumber(_ value: Decimal) -> Decimal {
        rounded(value, scale: 0, mode: .plain)
    }

    /// Crediti nella lingua di chi legge, da 0 a 2 decimali e con le migliaia: "1,158.4", "2.4", "1".
    static func format(_ value: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        value.formatted(Decimal.FormatStyle(locale: locale).precision(.fractionLength(0...2)))
    }

    /// Un importo nella valuta del server: intero senza centesimi (EUR 269), altrimenti da 2 a 4 decimali (un prezzo
    /// per credito di 0.16 si legge 0.16).
    static func formatMoney(_ value: Decimal, currency: String, locale: Locale = .autoupdatingCurrent) -> String {
        let isWhole = rounded(value, scale: 0, mode: .plain) == value
        let digits: ClosedRange<Int> = isWhole ? 0...0 : 2...4
        return value.formatted(Decimal.FormatStyle.Currency(code: currency, locale: locale).precision(.fractionLength(digits)))
    }

    /// "1 credit" o "2.4 credits": il singolare solo per esattamente 1 (come la web, che per 1.0 dice "1 credit").
    static func phrase(_ value: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        if value == 1 { return String(localized: "1 credit") }
        let figure = format(value, locale: locale)
        return String(localized: "\(figure) credits")
    }

    /// Un moltiplicatore con il segno × e senza spazio: 1.7 → "1.7×".
    static func formatMultiplier(_ value: Decimal, locale: Locale = .autoupdatingCurrent) -> String {
        "\(value.formatted(Decimal.FormatStyle(locale: locale).precision(.fractionLength(0...2))))×"
    }

    /// Una quota (0.72) come percentuale intera: 72.
    static func percent(_ share: Decimal) -> Int {
        wholePart(wholeNumber(share * 100))
    }

    private static func rounded(_ value: Decimal, scale: Int, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }

    /// La parte intera, per difetto (per i valori non negativi), come `Int`.
    static func wholePart(_ value: Decimal) -> Int {
        NSDecimalNumber(decimal: rounded(value, scale: 0, mode: .down)).intValue
    }
}
