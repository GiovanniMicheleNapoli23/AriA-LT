//
//  AdminScenarioFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si scrivono le cifre della sezione: percentuali, minuti, medie, voti e date. Un valore che manca
//  è un trattino, mai uno zero inventato.
//

import Foundation

nonisolated enum AdminScenarioFormat {
    static let missing = "—"

    /// I tassi arrivano come frazioni 0…1; un valore oltre 1 si legge come già in percentuale.
    static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        let fraction = value > 1.0001 ? value / 100 : value
        return fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    static func number(_ value: Double?, digits: Int = 1) -> String {
        guard let value, value.isFinite else { return missing }
        return value.formatted(.number.precision(.fractionLength(0...digits)))
    }

    static func count(_ value: Int?) -> String {
        value.map { $0.formatted() } ?? missing
    }

    /// "45 min", "1 h 20 min".
    static func minutes(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else { return missing }
        let seconds = (value * 60).rounded()
        if seconds < 60 { return Duration.seconds(seconds).formatted(.units(allowed: [.seconds], width: .abbreviated)) }
        return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// "4,2 / 5".
    static func rating(_ value: Double?) -> String {
        guard let value, value.isFinite else { return missing }
        return String(localized: "\(number(value)) / 5")
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return missing }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Fino a 5 stelle piene per un voto 1…5.
    static func stars(_ rating: Int?) -> String? {
        guard let rating, (1...5).contains(rating) else { return nil }
        return String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
    }
}
