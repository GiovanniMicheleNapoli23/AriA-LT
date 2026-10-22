//
//  AdminAgentStudioStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Stati ed esiti di Agent Studio (run, passi, approvazioni) come etichetta leggibile e tono di colore.
//  I valori arrivano come stringhe libere: quelli sconosciuti si mostrano ripuliti, in grigio.
//

import Foundation

/// Il tono di una pastiglia di stato; il colore lo sceglie il componente.
nonisolated enum AdminAgentStudioTone: Sendable {
    case positive, warning, negative, active, neutral
}

nonisolated enum AdminAgentStudioStatus {
    static func label(for raw: String) -> String {
        switch normalized(raw) {
        case "pending": String(localized: "Pending")
        case "approved": String(localized: "Approved")
        case "rejected": String(localized: "Rejected")
        case "expired": String(localized: "Expired")
        case "cancelled", "canceled": String(localized: "Cancelled")
        case "running": String(localized: "Running")
        case "queued": String(localized: "Queued")
        case "paused", "waiting", "awaiting_approval": String(localized: "Waiting")
        case "completed", "succeeded", "success", "done", "ok": String(localized: "Completed")
        case "completed_with_errors", "partial": String(localized: "Partial")
        case "failed", "error": String(localized: "Failed")
        case "ran": String(localized: "Ran")
        case "blocked": String(localized: "Blocked")
        case "unconfigured": String(localized: "Not configured")
        case "needs_approval": String(localized: "Needs approval")
        case "skipped": String(localized: "Skipped")
        case "refused": String(localized: "Refused")
        case "simulated": String(localized: "Simulated")
        case "ready": String(localized: "Ready")
        default:
            raw.replacingOccurrences(of: "_", with: " ").capitalized(with: .current)
        }
    }

    static func tone(for raw: String) -> AdminAgentStudioTone {
        switch normalized(raw) {
        case "approved", "completed", "succeeded", "success", "done", "ok", "ran", "ready", "simulated": .positive
        case "pending", "paused", "waiting", "awaiting_approval", "needs_approval", "unconfigured", "partial",
             "completed_with_errors": .warning
        case "rejected", "failed", "error", "blocked", "refused": .negative
        case "running", "queued": .active
        default: .neutral
        }
    }

    /// Un run che non è ancora finito: in corso o fermo ad aspettare una persona.
    static func isActive(_ raw: String) -> Bool {
        ["running", "queued", "pending", "paused", "waiting", "awaiting_approval", "needs_approval"]
            .contains(normalized(raw))
    }

    private static func normalized(_ raw: String) -> String {
        raw.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
    }
}
