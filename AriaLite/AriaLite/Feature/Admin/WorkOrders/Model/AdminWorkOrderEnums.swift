//
//  AdminWorkOrderEnums.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Stato, priorità, tipo e origine dell'assegnazione di un ordine di lavoro, come li scrive il backend.
//  Un valore nuovo del server diventa `.unknown` invece di far fallire la decodifica; `.unknown` non si
//  offre mai nei picker e non si rimanda al server.
//

import Foundation

nonisolated enum AdminWorkOrderStatus: String, AriaUnknownCaseDecodable, Hashable, CaseIterable {
    case proposed, planned, assigned
    case inProgress = "in_progress"
    case completed, verified, cancelled
    case unknown

    static var unknownCase: Self { .unknown }

    /// Quelli che si possono scegliere.
    static var known: [Self] { allCases.filter { $0 != .unknown } }

    /// Chiusi: completati, verificati o annullati (il gruppo `closed` della lista).
    var isClosed: Bool { [.completed, .verified, .cancelled].contains(self) }

    var localized: String {
        switch self {
        case .proposed: String(localized: "Proposed")
        case .planned: String(localized: "Planned")
        case .assigned: String(localized: "Assigned")
        case .inProgress: String(localized: "In progress")
        case .completed: String(localized: "Completed")
        case .verified: String(localized: "Verified")
        case .cancelled: String(localized: "Cancelled")
        case .unknown: String(localized: "Unknown")
        }
    }
}

nonisolated enum AdminWorkOrderPriority: String, AriaUnknownCaseDecodable, Hashable, CaseIterable {
    case high, medium, low
    case unknown

    static var unknownCase: Self { .unknown }
    static var known: [Self] { [.high, .medium, .low] }

    var localized: String {
        switch self {
        case .high: String(localized: "High")
        case .medium: String(localized: "Medium")
        case .low: String(localized: "Low")
        case .unknown: String(localized: "Unknown")
        }
    }
}

nonisolated enum AdminWorkOrderType: String, AriaUnknownCaseDecodable, Hashable, CaseIterable {
    case reactive, preventive
    case unknown

    static var unknownCase: Self { .unknown }
    static var known: [Self] { [.reactive, .preventive] }

    var localized: String {
        switch self {
        case .reactive: String(localized: "Reactive")
        case .preventive: String(localized: "Preventive")
        case .unknown: String(localized: "Unknown")
        }
    }
}

/// Chi ha assegnato l'ordine: l'assegnazione automatica o una persona.
nonisolated enum AdminWorkOrderAssignmentSource: String, AriaUnknownCaseDecodable, Hashable {
    case auto, manual
    case unknown

    static var unknownCase: Self { .unknown }

    var localized: String {
        switch self {
        case .auto: String(localized: "Auto")
        case .manual: String(localized: "Manual")
        case .unknown: String(localized: "Unknown")
        }
    }
}

/// Il parametro `status_group` della lista.
nonisolated enum AdminWorkOrderStatusGroup: String, Hashable, CaseIterable, Sendable {
    case open, closed, all

    var localized: String {
        switch self {
        case .open: String(localized: "Open")
        case .closed: String(localized: "Closed")
        case .all: String(localized: "All")
        }
    }
}
