//
//  AdminUsageSpendCapAmount.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il campo "Limit per cycle (EUR)" (contratto 5.1): la lettura dell'importo, il confronto con il minimo e quanti crediti
//  compra l'importo scritto. Quest'ultima è l'unica cifra che l'app calcola da sola: l'importo ÷ il prezzo di un credito
//  extra della config, per difetto.
//

import Foundation

nonisolated enum AdminUsageSpendCapAmount {
    nonisolated enum Check: Sendable, Equatable {
        case valid(Decimal)
        /// Non è un importo (forma sbagliata) oppure è sotto il minimo: "Enter an amount of {minimum} or more.", e non si manda niente.
        case invalid
    }

    /// Un importo valido: cifre con al più due decimali (punto o virgola) e non sotto `minimum` (se il server lo manda).
    static func check(_ text: String, minimum: Decimal?) -> Check {
        guard let amount = AdminUsageAmountInput.parse(text) else { return .invalid }
        if let minimum, amount < minimum { return .invalid }
        return .valid(amount)
    }

    /// I crediti interi che un importo compra al prezzo di un credito extra, per difetto (500 € a 0,16 = 3 125). `nil`
    /// senza prezzo (o con un prezzo non positivo): mai una cifra inventata.
    static func credits(buying amount: Decimal, at price: Decimal?) -> Decimal? {
        guard let price, price > 0, amount >= 0 else { return nil }
        var quotient = amount / price
        var rounded = Decimal()
        NSDecimalRound(&rounded, &quotient, 0, .down)
        return rounded
    }

    /// L'importo come lo scrive il campo (col punto, senza zeri in più): 500 → "500", 12.5 → "12.5".
    static func fieldText(_ amount: Decimal) -> String {
        AriaDecimal.wire(amount)
    }
}
