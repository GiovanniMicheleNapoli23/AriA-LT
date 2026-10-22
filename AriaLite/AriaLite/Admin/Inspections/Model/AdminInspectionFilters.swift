//
//  AdminInspectionFilters.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il filtro per scadenza della lista. Gli altri filtri (stato, stabilimento, asset, area) sono valori
//  presi dai dati; la lista del server non ha parametri, si filtra tutto qui sulle ispezioni scaricate.
//

import Foundation

nonisolated enum AdminInspectionDueFilter: String, CaseIterable, Identifiable, Sendable {
    case any, overdue, thisWeek, noDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .any: String(localized: "Any date")
        case .overdue: String(localized: "Overdue")
        case .thisWeek: String(localized: "Next 7 days")
        case .noDate: String(localized: "No due date")
        }
    }

    func matches(_ inspection: AdminInspection, now: Date = .now) -> Bool {
        switch self {
        case .any: true
        case .overdue: inspection.isOverdue(now: now)
        case .noDate: inspection.dueDate == nil
        case .thisWeek:
            if let due = inspection.dueDate, !inspection.isClosed {
                due >= Calendar.current.startOfDay(for: now) && due <= now.addingTimeInterval(7 * 24 * 3600)
            } else {
                false
            }
        }
    }
}
