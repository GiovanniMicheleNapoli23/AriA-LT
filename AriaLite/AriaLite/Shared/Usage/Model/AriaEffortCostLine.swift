//
//  AriaEffortCostLine.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La riga di costo di un livello di impegno nell'elenco: "2.4 credits per reply · about 72 a day". Le cifre sono
//  della stima del server (POST /v1/usage/estimate); senza stima si calcolano dalla config (peso × moltiplicatore,
//  per eccesso al passo) e il testo dice "up to". Stessa logica di effort-selector.tsx della web.
//

import Foundation

nonisolated struct AriaEffortCostLine: Equatable, Sendable {
    /// I crediti di una risposta a questo livello.
    let credits: Decimal
    /// Le risposte di una giornata piena; `nil` su un pool o senza una cifra giornaliera.
    let replies: Int?
    /// `true` quando la cifra è di una stima del server ("about"); `false` quando è calcolata dalla config ("up to").
    let isEstimate: Bool

    /// Una stima vale solo se è girata al livello chiesto (`effort_effective`) e ha `credits_each` leggibile: altrimenti si tratta come assente.
    /// `nil` (nessuna riga) se non c'è nessuna cifra: né stima né peso, moltiplicatore e passo nella config.
    static func make(config: AriaUsageConfig, level: AriaEffortLevel, estimate: AriaUsageEstimate?) -> AriaEffortCostLine? {
        // Una stima vale se è del livello chiesto e ha i crediti leggibili: altrimenti è come se non ci fosse e la riga
        // torna al calcolo ("up to"), mai "about" su una cifra che non c'è.
        let usable = estimate.flatMap { $0.effortEffective == level.rawValue && $0.creditsEach != nil ? $0 : nil }
        guard let credits = usable?.creditsEach ?? AriaCredits.creditsPerReply(config: config, level: level) else { return nil }
        let impact = usable?.allowanceImpactEach ?? credits
        return AriaEffortCostLine(
            credits: credits,
            replies: AriaCredits.repliesPerDay(creditsPerDay: config.plan?.creditsPerDay, cost: impact),
            isEstimate: usable != nil)
    }

    var text: String { formatted() }

    /// Il testo nella lingua dei numeri `locale`.
    func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        let amount = AriaCredits.phrase(credits, locale: locale)
        guard let replies else { return String(localized: "\(amount) per reply") }
        let perDay = replies.formatted(.number.locale(locale))
        return isEstimate
            ? String(localized: "\(amount) per reply · about \(perDay) a day")
            : String(localized: "\(amount) per reply · up to \(perDay) a day")
    }
}
