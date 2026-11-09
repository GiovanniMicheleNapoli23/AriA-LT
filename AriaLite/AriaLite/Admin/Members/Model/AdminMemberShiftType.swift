//
//  AdminMemberShiftType.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Tipo di turno, ruolo e giorni. L'OpenAPI dà `shift_type` e `role` come testo libero (predefinito `full`):
//  qui ci sono i valori che si propongono nei moduli; un valore sconosciuto del server si mostra com'è.
//

import Foundation

/// I tipi di turno proposti. Il server accetta testo libero: si manda la chiave.
nonisolated enum AdminMemberShiftType: String, CaseIterable, Identifiable, Sendable {
    case full, morning, afternoon, night

    var id: String { rawValue }

    var localized: String {
        switch self {
        case .full: String(localized: "Full day")
        case .morning: String(localized: "Morning")
        case .afternoon: String(localized: "Afternoon")
        case .night: String(localized: "Night")
        }
    }

    /// L'etichetta di una chiave qualsiasi: nota → tradotta, sconosciuta → il testo con la maiuscola.
    static func label(_ raw: String) -> String {
        if let known = Self(rawValue: raw.lowercased()) { return known.localized }
        return AdminMemberRole.pretty(raw)
    }
}

/// I ruoli: testo libero. Se ne propongono alcuni, più quelli già in uso fra i membri.
nonisolated enum AdminMemberRole {
    static let suggestions = ["admin", "supervisor", "technician", "viewer"]

    /// "shift_lead" → "Shift lead".
    static func pretty(_ raw: String) -> String {
        let text = raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    static func label(_ raw: String) -> String {
        switch raw.lowercased() {
        case "admin": String(localized: "Admin")
        case "supervisor": String(localized: "Supervisor")
        case "technician": String(localized: "Technician")
        case "viewer": String(localized: "Viewer")
        default: pretty(raw)
        }
    }

    /// La chiave per confrontare ruoli scritti in modo diverso ("Admin" e "admin" sono lo stesso).
    static func key(_ raw: String) -> String { raw.lowercased() }
}

/// I giorni dei turni come testo `YYYY-MM-DD`, sempre nel fuso del telefono: una data e il suo testo
/// tornano uguali senza slittare di giorno.
nonisolated enum AdminMemberDay {
    static func string(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return string(from: c)
    }

    static func string(from c: DateComponents) -> String {
        String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func date(from text: String) -> Date? {
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Da oggi fino a `days` giorni avanti, come testi `YYYY-MM-DD`.
    static func window(days: Int, from now: Date = .now) -> (from: String, to: String) {
        let end = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        return (string(from: now), string(from: end))
    }
}
