//
//  AdminCraftedVerdict.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si legge il verdetto di una sessione e da dove viene. I valori sono quelli del riepilogo del
//  server (resolved, unresolved, unclear); uno sconosciuto si mostra com'è.
//

import SwiftUI

nonisolated enum AdminCraftedVerdict {
    static func label(_ verdict: String?) -> String {
        switch verdict?.lowercased() {
        case "resolved"?: String(localized: "Resolved")
        case "unresolved"?: String(localized: "Unresolved")
        case "unclear"?: String(localized: "Unclear")
        case nil, ""?: String(localized: "No verdict")
        case let other?: other.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func tint(_ verdict: String?) -> Color {
        switch verdict?.lowercased() {
        case "resolved"?: .green
        case "unresolved"?: .red
        case "unclear"?: .orange
        default: .secondary
        }
    }

    static func systemImage(_ verdict: String?) -> String {
        switch verdict?.lowercased() {
        case "resolved"?: "checkmark.seal"
        case "unresolved"?: "xmark.octagon"
        case "unclear"?: "questionmark.circle"
        default: "circle.dashed"
        }
    }

    /// Chi ha deciso: un verdetto confermato da una persona vale più di quello che Aria ha dedotto da sola.
    static func sourceLabel(_ source: String?) -> String? {
        switch source?.lowercased() {
        case nil, ""?: nil
        case "operator"?, "review"?, "operator_review"?: String(localized: "Confirmed by the operator")
        case "admin"?, "admin_correction"?, "correction"?: String(localized: "Corrected by an admin")
        case "aria"?, "auto"?, "inferred"?, "transcript"?, "model"?: String(localized: "Inferred by Aria")
        case let other?: other.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
