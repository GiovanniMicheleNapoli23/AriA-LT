//
//  AdminCraftedKind.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I tipi di card che Aria crea (`kind` di un widget o di un artifact): nome da mostrare, icona e quali
//  sa disegnare l'app con le card della chat (AriaArtifactView). Un tipo nuovo del server resta leggibile.
//

import Foundation

nonisolated enum AdminCraftedKind {
    /// I tipi che AriaArtifactView disegna: gli altri si mostrano come contenuto strutturato.
    static let drawable: Set<String> = [
        "wo-card", "table", "kpi-grid", "chart", "asset-card", "maintenance-plan-card", "diagnostic-card",
        "alarm-toast", "dashboard", "reassignment-plan", "assignment-suggestion", "similar-wo-list",
        "spare-parts-recommendation", "triage-plan", "member-absence-plan", "team-kanban",
    ]

    static func label(_ kind: String) -> String {
        switch kind {
        case "table": String(localized: "Table")
        case "chart": String(localized: "Chart")
        case "kpi-grid": String(localized: "KPIs")
        case "dashboard": String(localized: "Dashboard")
        case "wo-card": String(localized: "Work order")
        case "asset-card": String(localized: "Asset")
        case "maintenance-plan-card": String(localized: "Maintenance plan")
        case "diagnostic-card": String(localized: "Diagnosis")
        case "alarm-toast": String(localized: "Alarm")
        case "team-kanban": String(localized: "Team board")
        case "": String(localized: "Widget")
        default:
            // "spare-parts-recommendation" → "Spare parts recommendation"
            sentence(kind.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " "))
        }
    }

    /// Solo la prima lettera maiuscola.
    private static func sentence(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    static func systemImage(_ kind: String) -> String {
        switch kind {
        case "table": "tablecells"
        case "chart": "chart.xyaxis.line"
        case "kpi-grid": "square.grid.2x2"
        case "dashboard": "rectangle.3.group"
        case "wo-card", "similar-wo-list": "wrench.and.screwdriver"
        case "asset-card": "gearshape.2"
        case "maintenance-plan-card": "calendar.badge.clock"
        case "diagnostic-card": "stethoscope"
        case "alarm-toast", "triage-plan": "bell.badge"
        case "team-kanban", "reassignment-plan", "member-absence-plan", "assignment-suggestion": "person.3"
        case "spare-parts-recommendation": "shippingbox"
        default: "sparkles"
        }
    }
}
