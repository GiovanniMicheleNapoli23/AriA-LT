//
//  AdminTeamWorkOrderStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli stati e le priorità di un ordine di lavoro come li usa la bacheca della squadra: etichetta, icona e colore.
//

import SwiftUI

nonisolated enum AdminTeamWorkOrderStatus: String, CaseIterable, Sendable, Hashable {
    case proposed, planned, assigned
    case inProgress = "in_progress"
    case completed, verified, cancelled
    case unknown

    /// Legge lo stato come lo scrive il server; anche `inProgress` o `In Progress` (chiavi riscritte) vanno bene.
    init(key: String?) {
        let normal = (key ?? "").lowercased().filter { $0 != "_" && $0 != " " && $0 != "-" }
        self = Self.allCases.first { $0.rawValue.replacingOccurrences(of: "_", with: "") == normal } ?? .unknown
    }

    /// Le colonne della bacheca, nell'ordine del flusso.
    static var known: [Self] { allCases.filter { $0 != .unknown } }

    var isClosed: Bool { self == .completed || self == .verified || self == .cancelled }

    /// Dove si può portare un ordine dalla bacheca. "Completed" e "Verified" no: chiedono note di chiusura e
    /// passi risolti, e passano dagli ordini di lavoro.
    static var moveTargets: [Self] { [.proposed, .planned, .assigned, .inProgress, .cancelled] }

    var label: String {
        switch self {
        case .proposed: String(localized: "Proposed")
        case .planned: String(localized: "Planned")
        case .assigned: String(localized: "Assigned")
        case .inProgress: String(localized: "In progress")
        case .completed: String(localized: "Completed")
        case .verified: String(localized: "Verified")
        case .cancelled: String(localized: "Cancelled")
        case .unknown: String(localized: "Other")
        }
    }

    var systemImage: String {
        switch self {
        case .proposed: "lightbulb"
        case .planned: "calendar"
        case .assigned: "person.crop.circle.badge.checkmark"
        case .inProgress: "play.circle"
        case .completed: "checkmark.circle"
        case .verified: "checkmark.seal"
        case .cancelled: "xmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .proposed: .purple
        case .planned: .blue
        case .assigned: .indigo
        case .inProgress: .orange
        case .completed: .green
        case .verified: .teal
        case .cancelled: .gray
        case .unknown: .secondary
        }
    }
}

nonisolated enum AdminTeamWorkOrderPriority: String, Sendable, Hashable {
    case high, medium, low, unknown

    init(key: String?) {
        self = Self(rawValue: (key ?? "").lowercased()) ?? .unknown
    }

    /// Ordine di urgenza: prima le alte.
    var rank: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        case .unknown: 3
        }
    }

    var label: String {
        switch self {
        case .high: String(localized: "High")
        case .medium: String(localized: "Medium")
        case .low: String(localized: "Low")
        case .unknown: String(localized: "Other")
        }
    }

    var tint: Color {
        switch self {
        case .high: .red
        case .medium: .orange
        case .low: .green
        case .unknown: .secondary
        }
    }
}
