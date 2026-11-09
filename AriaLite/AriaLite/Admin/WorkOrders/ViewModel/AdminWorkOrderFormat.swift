//
//  AdminWorkOrderFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si scrivono date, durate e importi degli ordini nelle schermate admin.
//

import Foundation

enum AdminWorkOrderFormat {
    /// "22 ott 2026, 10:30".
    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Scadenza nella riga della lista: corta, senza anno.
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    /// "1 h 30 min".
    static func duration(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    static func hours(_ hours: Double) -> String {
        Duration.seconds(hours * 3600).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// Importo senza valuta: il backend non dice quale sia.
    static func amount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    /// Elementi non vuoti uniti da " · ".
    static func joined(_ parts: [String?]) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
