//
//  AdminAlarmImprove.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" di un allarme: le azioni offerte e i campi che l'AI può proporre. L'OpenAPI dice solo
//  `action: string`: i valori sono IPOTESI (un 400/422 mostra quelli validi, da correggere qui).
//

import Foundation

nonisolated enum AdminAlarmImproveAction: String, CaseIterable, Identifiable, Sendable {
    // Valori indovinati: da verificare col backend.
    case improve = "improve"
    case complete = "complete"
    case translate = "translate"
    /// Richiesta libera: il testo va in `custom_prompt`.
    case custom = "custom"

    var id: String { rawValue }

    /// Le scorciatoie senza testo da scrivere.
    static let shortcuts: [Self] = [.improve, .complete, .translate]

    var title: String {
        switch self {
        case .improve: String(localized: "Improve")
        case .complete: String(localized: "Fill in missing fields")
        case .translate: String(localized: "Translate to my language")
        case .custom: String(localized: "Custom request")
        }
    }

    var subtitle: String {
        switch self {
        case .improve: String(localized: "Clearer description, causes and steps")
        case .complete: String(localized: "Add what the alarm is missing")
        case .translate: String(localized: "Rewrite the texts in your language")
        case .custom: String(localized: "Ask for something specific")
        }
    }

    var systemImage: String {
        switch self {
        case .improve: "wand.and.stars"
        case .complete: "text.badge.plus"
        case .translate: "character.bubble"
        case .custom: "text.bubble"
        }
    }
}

/// I campi di un allarme che l'AI può proporre di cambiare.
nonisolated enum AdminAlarmField: String, CaseIterable, Identifiable, Sendable {
    case description, category, zone, hmiPage, typicalCauses, resolutionSteps

    var id: String { rawValue }

    var label: String {
        switch self {
        case .description: String(localized: "Description")
        case .category: String(localized: "Category")
        case .zone: String(localized: "Zone")
        case .hmiPage: String(localized: "HMI page")
        case .typicalCauses: String(localized: "Typical causes")
        case .resolutionSteps: String(localized: "Resolution steps")
        }
    }

    /// Un elenco di righe invece di un testo solo.
    var isList: Bool { self == .typicalCauses || self == .resolutionSteps }

    /// Le chiavi sotto cui il server può mandare il campo (camelCase, senza distinguere le maiuscole).
    var responseKeys: [String] {
        switch self {
        case .description: ["description"]
        case .category: ["category"]
        case .zone: ["zone"]
        case .hmiPage: ["hmiPage"]
        case .typicalCauses: ["typicalCauses", "causes"]
        case .resolutionSteps: ["resolutionSteps", "steps"]
        }
    }
}
