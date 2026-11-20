//
//  AriaTrialOffer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Tutto quello che la card della demo gratuita dice, già pronto: durata, prezzo, le tre cifre, le righe incluse e
//  gli altri piani. Dal listino pubblico e dalla lingua; la view non decide niente (stesse regole della web:
//  trial-card.tsx e plan-cards.ts).
//

import Foundation

nonisolated struct AriaTrialOffer: Sendable, Equatable {
    /// Una cifra della prova: il numero sopra, l'unità sotto.
    nonisolated struct Figure: Sendable, Equatable, Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }

    /// Una riga di "Other plans".
    nonisolated struct PlanRow: Sendable, Equatable, Identifiable {
        nonisolated enum Kind: Sendable, Equatable {
            /// Piano a pagamento non ancora aperto.
            case soon
            /// Piano a contratto: si scrive alle vendite.
            case contact(URL)
        }

        let id: String
        let name: String
        let tagline: String
        let kind: Kind

        /// "Soon" o "Contact", a destra della riga.
        var trailing: String {
            switch kind {
            case .soon: String(localized: "Soon")
            case .contact: String(localized: "plans.contact", defaultValue: "Contact")
            }
        }

        /// Per VoiceOver: nome, tagline e cosa succede toccandola.
        var accessibilityLabel: String {
            let action = switch kind {
            case .soon: String(localized: "Soon")
            case .contact: String(localized: "Contact sales")
            }
            return [name, tagline, action].joined(separator: ", ")
        }
    }

    /// L'indirizzo delle vendite quando il listino non lo dice.
    static let defaultSalesEmail = "sales@sinaura.com"

    /// Nomi dei piani, uguali in ogni lingua. Le chiavi sono quelle del listino.
    private static let tierNames = ["basic": "Basic", "basic_plus": "Basic Plus", "professional": "Professional",
                                    "enterprise": "Enterprise", "enterprise_ar_plus": "Enterprise AR+"]

    /// Il listino sta ancora arrivando: le cifre sono barre grigie.
    let isLoading: Bool
    /// Durata della prova in giorni; `nil` se il listino non la dice o non è positiva.
    let days: Int?
    let name: String
    let badge: String
    /// "Try AriaPLT free for 14 days" o, senza durata, "Try AriaPLT free".
    let tagline: String
    let noCard: String
    /// Il prezzo del contratto della prova ("€0") con la sua unità ("for 14 days"); `nil` senza listino.
    let price: String?
    let priceUnit: String?
    let figures: [Figure]
    /// "Runs on the Basic plan with these limits:"; `nil` senza prova nel listino.
    let runsOn: String?
    let lines: [String]
    let otherPlans: [PlanRow]
    let otherPlansTitle: String
    let legalPrefix: String
    let legalLink: String
    let termsURL: URL

    /// "Try AriaPLT free for 14 days · No card required".
    var subtitle: String { "\(tagline) · \(noCard)" }

    /// `language`: la lingua dell'app, per il link ai termini (italiano o inglese).
    init(state: AriaPriceListState, locale: Locale = .current,
         language: String = Bundle.main.preferredLocalizations.first ?? "en") {
        let list = state.list
        let trial = list?.trial
        let days = trial.flatMap { $0.days > 0 ? $0.days : nil }
        isLoading = state == .loading
        self.days = days
        name = String(localized: "Free demo")
        badge = String(localized: "Free trial")
        tagline = days.map { String(localized: "Try AriaPLT free for \($0) days") } ?? String(localized: "Try AriaPLT free")
        noCard = String(localized: "No card required")
        let price = trial?.contractPrice.map { Self.money($0, currency: list?.currency ?? "EUR", locale: locale) }
        self.price = price
        priceUnit = price == nil ? nil : trial.map { String(localized: "for \($0.days) days") }
        figures = Self.makeFigures(trial, locale: locale)
        runsOn = trial.map { String(localized: "Runs on the \(Self.tierName($0.tier)) plan with these limits:") }
        lines = Self.makeLines(state: state, list: list, trial: trial, locale: locale)
        otherPlans = Self.makeOtherPlans(salesEmail: state.salesEmail)
        otherPlansTitle = String(localized: "Other plans")
        legalPrefix = String(localized: "By continuing, you acknowledge Sinaura · AriaPLT's")
        legalLink = String(localized: "Privacy Policy")
        termsURL = Self.termsLink(language: language)
    }

    /// Il testo del pulsante che chiude l'iscrizione.
    func ctaTitle(isSaving: Bool) -> LocalizedStringResource {
        if isSaving { return "Starting your trial…" }
        if let days { return "Start the \(days)-day free trial" }
        return "Start the free trial"
    }

    /// I termini sul sito di Sinaura, in italiano se l'app è in italiano e in inglese per il resto.
    static func termsLink(language: String) -> URL {
        let code = language.lowercased().hasPrefix("it") ? "it" : "en"
        return URL(string: "https://www.sinauragroup.com/\(code)/legal/terms-of-service")!
    }

    /// Il nome di un piano dalla sua chiave ("basic_plus" → "Basic Plus"); una chiave nuova si legge com'è.
    static func tierName(_ key: String) -> String {
        tierNames[key] ?? key.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    // MARK: Formati

    /// Un formattatore per lingua e stile, creato una volta sola.
    private static let formatters = AriaLocaleFormatterCache<NumberFormatter>()

    static func number(_ value: Int, locale: Locale) -> String {
        let formatter = formatters.formatter(variant: "decimal", locale: locale) {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            return formatter
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Giga con al più un decimale, come lo scrive la lingua.
    static func gigabytes(_ value: Double, locale: Locale) -> String {
        let formatter = formatters.formatter(variant: "gigabytes", locale: locale) {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Un importo intero senza decimali ("€0"), gli altri da 2 a 4 ("€0.10").
    static func money(_ value: Decimal, currency: String, locale: Locale) -> String {
        let number = NSDecimalNumber(decimal: value)
        let whole = Decimal(number.intValue) == value
        let formatter = formatters.formatter(variant: "money|\(currency)|\(whole)", locale: locale) {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .currency
            formatter.currencyCode = currency
            formatter.minimumFractionDigits = whole ? 0 : 2
            formatter.maximumFractionDigits = whole ? 0 : 4
            return formatter
        }
        return formatter.string(from: number) ?? "\(value)"
    }
}
