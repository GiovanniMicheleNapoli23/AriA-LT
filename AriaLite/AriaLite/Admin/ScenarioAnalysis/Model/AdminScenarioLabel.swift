//
//  AdminScenarioLabel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Etichette e toni dei valori testuali del server (verdetto, fonte, tendenza, maturità…). Quelli noti
//  si traducono; uno sconosciuto si mostra leggibile ("first_shot" → "First shot") invece di sparire.
//

import Foundation

nonisolated enum AdminScenarioLabel {
    /// `snake_case` o `kebab-case` → "Prima lettera maiuscola".
    static func humanized(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    // MARK: Verdetto

    static func verdict(_ raw: String) -> String {
        switch raw.lowercased() {
        case "resolved", "success", "fixed": String(localized: "Resolved")
        case "partial": String(localized: "Partially resolved")
        case "unresolved", "failure", "failed": String(localized: "Unresolved")
        case "unclear", "unknown", "inconclusive": String(localized: "Unclear")
        default: humanized(raw)
        }
    }

    static func verdictTone(_ raw: String?) -> AdminScenarioTone {
        switch raw?.lowercased() {
        case "resolved", "success", "fixed": .positive
        case "partial": .warning
        case "unresolved", "failure", "failed": .negative
        default: .neutral
        }
    }

    /// Chi ha dato il verdetto.
    static func verdictSource(_ raw: String) -> String {
        switch raw.lowercased() {
        case "operator", "operator_review", "user": String(localized: "Confirmed by operator")
        case "admin", "admin_review", "owner": String(localized: "Corrected by admin")
        case "aria", "model", "llm", "auto", "inferred", "transcript", "assessment":
            String(localized: "Aria's own reading")
        default: humanized(raw)
        }
    }

    /// Fonte del verdetto confermata da una persona.
    static func isHumanSource(_ raw: String?) -> Bool {
        guard let raw = raw?.lowercased() else { return false }
        return ["operator", "operator_review", "user", "admin", "admin_review", "owner"].contains(raw)
    }

    // MARK: Scenario

    static func trend(_ raw: String) -> String {
        switch raw.lowercased() {
        case "improving", "up": String(localized: "Improving")
        case "declining", "worsening", "down": String(localized: "Declining")
        case "stable", "flat": String(localized: "Stable")
        case "new", "insufficient", "insufficient_data", "unknown": String(localized: "Not enough data")
        default: humanized(raw)
        }
    }

    static func trendSystemImage(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "improving", "up": "arrow.up.right"
        case "declining", "worsening", "down": "arrow.down.right"
        case "stable", "flat": "arrow.right"
        default: "minus"
        }
    }

    static func trendTone(_ raw: String?) -> AdminScenarioTone {
        switch raw?.lowercased() {
        case "improving", "up": .positive
        case "declining", "worsening", "down": .negative
        default: .neutral
        }
    }

    static func maturity(_ raw: String) -> String {
        switch raw.lowercased() {
        case "proven": String(localized: "Proven")
        case "emerging", "developing": String(localized: "Emerging")
        case "new", "nascent", "unproven": String(localized: "New")
        case "unreliable", "failing": String(localized: "Unreliable")
        default: humanized(raw)
        }
    }

    static func maturityTone(_ raw: String?) -> AdminScenarioTone {
        switch raw?.lowercased() {
        case "proven": .positive
        case "emerging", "developing": .info
        case "unreliable", "failing": .negative
        default: .neutral
        }
    }

    static func confidence(_ raw: String) -> String {
        switch raw.lowercased() {
        case "high": String(localized: "High confidence")
        case "medium", "moderate": String(localized: "Medium confidence")
        case "low": String(localized: "Low confidence")
        case "none", "insufficient": String(localized: "No basis yet")
        default: humanized(raw)
        }
    }

    // MARK: Chiusure

    static func closureTone(_ raw: String?) -> AdminScenarioTone {
        switch raw.flatMap(AdminScenarioClosureStatus.init(rawValue:)) {
        case .unread: .warning
        case .read: .info
        case .approved: .positive
        case .reassigned: .negative
        case .dismissed, nil: .neutral
        }
    }

    // MARK: Passi e feedback

    static func stepOutcomeTone(_ raw: String?) -> AdminScenarioTone {
        switch raw?.lowercased() {
        case "done", "ok", "completed", "success", "passed", "resolved": .positive
        case "failed", "failure", "error": .negative
        case "confused", "confusion", "revised", "revision", "skipped", "customized": .warning
        default: .neutral
        }
    }
}
