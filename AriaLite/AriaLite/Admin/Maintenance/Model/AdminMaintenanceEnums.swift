//
//  AdminMaintenanceEnums.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Frequenza, stato, giorni della settimana e urgenza di un piano di manutenzione, come li scrive il backend.
//  I valori restano stringhe nel modello: uno nuovo del server si mostra com'è invece di far fallire la lettura.
//

import Foundation

nonisolated enum AdminMaintenanceFrequency: String, CaseIterable, Identifiable, Sendable {
    case daily, weekly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: String(localized: "Daily")
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "sun.max"
        case .weekly: "calendar.badge.clock"
        case .monthly: "calendar"
        case .yearly: "calendar.badge.checkmark"
        }
    }

    /// Un valore sconosciuto si mostra con le sue parole ("every_2_weeks" → "Every 2 weeks").
    static func label(for raw: String) -> String {
        if let known = Self(rawValue: raw) { return known.label }
        let words = raw.replacing("_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

/// EntityStatus: i piani della lista sono `approved`, le bozze di estrazione `draft` o `staged`.
nonisolated enum AdminMaintenanceStatus: String, CaseIterable, Identifiable, Sendable {
    case approved, draft, staged, rejected, superseded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .approved: String(localized: "Approved")
        case .draft: String(localized: "Draft")
        case .staged: String(localized: "Staged")
        case .rejected: String(localized: "Rejected")
        case .superseded: String(localized: "Superseded")
        }
    }

    static func label(for raw: String) -> String {
        if let known = Self(rawValue: raw) { return known.label }
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }
}

/// I giorni di `days_of_week`, in ordine di settimana.
nonisolated enum AdminMaintenanceWeekday: String, CaseIterable, Identifiable, Sendable {
    case mon, tue, wed, thu, fri, sat, sun

    var id: String { rawValue }

    /// Indice nel calendario (domenica = 1).
    private var calendarIndex: Int {
        switch self {
        case .sun: 0
        case .mon: 1
        case .tue: 2
        case .wed: 3
        case .thu: 4
        case .fri: 5
        case .sat: 6
        }
    }

    /// "Mon", "lun"… nella lingua dell'app.
    var shortLabel: String { Calendar.current.shortWeekdaySymbols[calendarIndex] }

    static func shortLabel(for raw: String) -> String {
        Self(rawValue: raw.lowercased())?.shortLabel ?? raw
    }
}

/// Quanto è vicina la prossima scadenza.
nonisolated enum AdminMaintenanceDueState: String, CaseIterable, Identifiable, Sendable {
    case overdue, dueSoon, later, unscheduled

    var id: String { rawValue }

    /// "In scadenza" = entro questi giorni.
    static let soonDays = 7

    var label: String {
        switch self {
        case .overdue: String(localized: "Overdue")
        case .dueSoon: String(localized: "Due soon")
        case .later: String(localized: "Scheduled")
        case .unscheduled: String(localized: "Not scheduled")
        }
    }

    var systemImage: String {
        switch self {
        case .overdue: "exclamationmark.triangle.fill"
        case .dueSoon: "clock.badge.exclamationmark"
        case .later: "calendar"
        case .unscheduled: "calendar.badge.minus"
        }
    }

    static func state(for dueDate: Date?, now: Date = .now) -> Self {
        guard let dueDate else { return .unscheduled }
        if dueDate < now { return .overdue }
        let limit = Calendar.current.date(byAdding: .day, value: soonDays, to: now) ?? now
        return dueDate <= limit ? .dueSoon : .later
    }
}
