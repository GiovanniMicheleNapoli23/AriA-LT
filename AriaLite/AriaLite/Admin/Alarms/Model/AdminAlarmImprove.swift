//
//  AdminAlarmImprove.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" di un allarme: le azioni offerte e i campi che l'AI può proporre. I valori di `action`
//  sono quelli della web (AlarmAIImproveAction in lib/api/cmms-types.ts di aria-web): un valore che il
//  server non conosce torna come {"status": "error"} (vedi AdminAIImproveStatus).
//

import Foundation

nonisolated enum AdminAlarmImproveAction: String, CaseIterable, Identifiable, Sendable {
    case improveAll = "improve_all"
    case improveDescription = "improve_description"
    case improveCauses = "improve_causes"
    case improveResolution = "improve_resolution"
    /// Traduce i testi nella lingua di `language`.
    case translate = "translate"
    /// Richiesta libera: il testo va in `custom_prompt`.
    case custom = "custom"

    var id: String { rawValue }

    /// Una parte sola dell'allarme, sotto l'azione principale (`improveAll`).
    static let parts: [Self] = [.improveDescription, .improveCauses, .improveResolution]

    var title: String {
        switch self {
        case .improveAll: String(localized: "Improve everything")
        case .improveDescription: String(localized: "Rewrite the description")
        case .improveCauses: String(localized: "Rewrite the typical causes")
        case .improveResolution: String(localized: "Rewrite the resolution steps")
        case .translate: String(localized: "Translate")
        case .custom: String(localized: "Ask something else")
        }
    }

    var subtitle: String {
        switch self {
        case .improveAll: String(localized: "Description, typical causes and resolution steps together.")
        case .improveDescription: String(localized: "Clearer and more precise")
        case .improveCauses: String(localized: "More complete and specific")
        case .improveResolution: String(localized: "Clear steps, in the right order")
        case .translate: String(localized: "Rewrites the texts in the chosen language")
        case .custom: String(localized: "Ask for something specific")
        }
    }

    var systemImage: String {
        switch self {
        case .improveAll: "wand.and.stars"
        case .improveDescription: "text.alignleft"
        case .improveCauses: "questionmark.diamond"
        case .improveResolution: "list.number"
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
