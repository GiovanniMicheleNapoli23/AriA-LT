//
//  AdminLLMUsageFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si scrivono denaro, token e durate nella sezione: stessi formati in tutte le schede.
//

import Foundation

enum AdminLLMUsageFormat {
    /// Il riepilogo è in euro (`cost_eur`); il listino porta la sua valuta.
    static let summaryCurrency = "EUR"

    static func money(_ value: Double, currency: String = summaryCurrency) -> String {
        value.formatted(.currency(code: currency).precision(.fractionLength(2...4)))
    }

    static func tokens(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName))
    }

    static func duration(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow))
    }
}
