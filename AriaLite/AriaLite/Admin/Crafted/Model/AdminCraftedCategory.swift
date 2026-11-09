//
//  AdminCraftedCategory.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  I filtri della lista Crafted (CRAFTED_CATEGORIES della web): i tipi raggruppati per quello che si
//  cerca, non per come li etichetta lo stream — "un piano" è quello di manutenzione e il triage.
//  `pending` raccoglie ciò che Aria non ha ancora finito.
//

import Foundation

nonisolated enum AdminCraftedCategory: String, CaseIterable, Identifiable, Sendable {
    case documents, charts, tables, dashboards, plans, workOrders, boards, pending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .documents: String(localized: "Documents")
        case .charts: String(localized: "Charts")
        case .tables: String(localized: "Tables")
        case .dashboards: String(localized: "Dashboards")
        case .plans: String(localized: "Plans")
        case .workOrders: String(localized: "Work orders")
        case .boards: String(localized: "Boards")
        case .pending: String(localized: "Not ready")
        }
    }

    var systemImage: String {
        switch self {
        case .documents: "doc.text"
        case .charts: "chart.xyaxis.line"
        case .tables: "tablecells"
        case .dashboards: "rectangle.3.group"
        case .plans: "list.clipboard"
        case .workOrders: "wrench.and.screwdriver"
        case .boards: "rectangle.split.3x1"
        case .pending: "hourglass"
        }
    }

    /// I tipi che finiscono qui.
    var kinds: [String] {
        switch self {
        case .documents: ["report", "document"]
        case .charts: ["chart"]
        case .tables: ["table", "kpi-grid"]
        case .dashboards: ["dashboard"]
        case .plans: ["maintenance-plan-card", "triage-plan", "reassignment-plan", "assignment-suggestion", "member-absence-plan"]
        case .workOrders: ["wo-card"]
        case .boards: ["team-kanban"]
        case .pending: []
        }
    }

    /// La categoria di un tipo; quello che non è elencato si legge come documento.
    static func of(kind: String) -> AdminCraftedCategory {
        allCases.first { $0.kinds.contains(kind) } ?? .documents
    }
}

nonisolated extension AdminCraftedCategory {
    /// Come lo chiama la web (`categoryOf`).
    static func categoryOf(_ kind: String) -> AdminCraftedCategory { of(kind: kind) }
}
