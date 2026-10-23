//
//  AdminCraftedKind.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I tipi di cosa che Aria crea (CRAFTED_KINDS della web, più quelli che il server può mandare in
//  più): nome da mostrare, icona, frase d'esempio del composer e quali sa disegnare l'app con le card
//  della chat (AriaArtifactView). Un tipo nuovo del server resta leggibile.
//

import Foundation

nonisolated enum AdminCraftedKind {
    /// I tipi della pagina, nell'ordine in cui si elencano (il primo, `report`, nasce fuori da Crafted).
    static let all: [String] = [
        "report", "chart", "dashboard", "table", "kpi-grid", "wo-card", "maintenance-plan-card", "triage-plan", "team-kanban",
    ]

    /// I tipi che AriaArtifactView disegna: gli altri si mostrano come contenuto strutturato.
    static let drawable: Set<String> = [
        "wo-card", "table", "kpi-grid", "chart", "asset-card", "maintenance-plan-card", "diagnostic-card",
        "alarm-toast", "dashboard", "reassignment-plan", "assignment-suggestion", "similar-wo-list",
        "spare-parts-recommendation", "triage-plan", "member-absence-plan", "team-kanban",
    ]

    static func label(_ kind: String) -> String {
        switch kind {
        case "report": String(localized: "Intervention report")
        case "table": String(localized: "Table")
        case "chart": String(localized: "Chart")
        case "kpi-grid": String(localized: "KPI grid")
        case "dashboard": String(localized: "Dashboard")
        case "wo-card": String(localized: "Work order")
        case "asset-card": String(localized: "Asset")
        case "maintenance-plan-card": String(localized: "Maintenance plan")
        case "triage-plan": String(localized: "Triage plan")
        case "reassignment-plan": String(localized: "Reassignment plan")
        case "assignment-suggestion": String(localized: "Suggested assignment")
        case "member-absence-plan": String(localized: "Absence plan")
        case "diagnostic-card": String(localized: "Diagnosis")
        case "alarm-toast": String(localized: "Alarm")
        case "team-kanban": String(localized: "Team board")
        case "document": String(localized: "Document")
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
        case "report", "document": "doc.text"
        case "table": "tablecells"
        case "chart": "chart.xyaxis.line"
        case "kpi-grid": "gauge.with.dots.needle.67percent"
        case "dashboard": "rectangle.3.group"
        case "wo-card", "similar-wo-list": "wrench.and.screwdriver"
        case "asset-card": "gearshape.2"
        case "maintenance-plan-card": "list.clipboard"
        case "diagnostic-card": "stethoscope"
        case "alarm-toast": "bell.badge"
        case "triage-plan": "checklist"
        case "team-kanban": "rectangle.split.3x1"
        case "reassignment-plan", "member-absence-plan", "assignment-suggestion": "person.3"
        case "spare-parts-recommendation": "shippingbox"
        default: "sparkles"
        }
    }

    // MARK: Esempi del composer

    /// Una frase d'esempio per tipo ("Oppure parti da un esempio"): toccarla riempie il campo.
    nonisolated struct Example: Identifiable, Hashable, Sendable {
        let kind: String
        let text: String
        var id: String { kind }
    }

    /// Gli esempi nell'ordine della web (compose.examples): `report` non ne ha, nasce da una procedura.
    static var examples: [Example] {
        ["chart", "table", "kpi-grid", "maintenance-plan-card", "dashboard", "wo-card", "triage-plan", "team-kanban"]
            .compactMap { kind in example(kind).map { Example(kind: kind, text: $0) } }
    }

    static func example(_ kind: String) -> String? {
        switch kind {
        case "chart": String(localized: "Downtime by cause on line 2, over the last 30 days")
        case "table": String(localized: "Spare parts below minimum stock, with supplier and lead time")
        case "kpi-grid": String(localized: "OEE, scrap and downtime minutes for the night shift")
        case "maintenance-plan-card": String(localized: "Monthly lubrication of the line 1 conveyors")
        case "dashboard": String(localized: "Availability, MTBF and open work orders for the plant, by line")
        case "wo-card": String(localized: "Replace the bearings on pump P-101 by Friday")
        case "triage-plan": String(localized: "Three alarms active on the packaging line: where do I start?")
        case "team-kanban": String(localized: "The electrical team's jobs for this week")
        default: nil
        }
    }
}
