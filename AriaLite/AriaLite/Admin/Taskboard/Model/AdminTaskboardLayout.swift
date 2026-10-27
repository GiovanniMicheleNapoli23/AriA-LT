//
//  AdminTaskboardLayout.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Come si guarda la bacheca: kanban (tutte le colonne affiancate, ognuna con il suo scroll, le card si
//  trascinano fra le colonne), lista (una colonna alla volta su telefono, griglia su schermi larghi), persone
//  (le task aperte divise per chi le esegue) o calendario (il mese e le attività del giorno, per persona).
//

import Foundation

nonisolated enum AdminTaskboardLayout: String, CaseIterable, Sendable {
    case kanban, list, people, calendar

    var localized: String {
        switch self {
        case .kanban: String(localized: "Kanban")
        case .list: String(localized: "List")
        case .people: String(localized: "People")
        case .calendar: String(localized: "Calendar")
        }
    }

    var systemImage: String {
        switch self {
        case .kanban: "rectangle.split.3x1"
        case .list: "rectangle.grid.1x2"
        case .people: "person.2"
        case .calendar: "calendar"
        }
    }
}
