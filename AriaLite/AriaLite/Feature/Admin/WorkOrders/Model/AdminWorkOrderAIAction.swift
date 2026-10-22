//
//  AdminWorkOrderAIAction.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni dell'AI sugli ordini (POST /v1/work-orders/{id}/ai-assist e /v1/work-orders/ai-draft) e i
//  loro body. L'OpenAPI dice solo `action: string`: i valori qui sotto sono IPOTESI. Se il server ne
//  rifiuta uno (400/422) l'assistente mostra il dettaglio e, se c'è, l'elenco di quelli validi:
//  basta correggere il `rawValue` qui.
//

import Foundation

nonisolated enum AdminWorkOrderAIAction: String, CaseIterable, Identifiable, Sendable {
    // Valori indovinati: da verificare col backend.
    case completeDraft = "complete"
    case improveDescription = "improve_description"
    case generateSteps = "generate_steps"
    case estimateDuration = "estimate_duration"
    case suggestParts = "suggest_parts"
    case safetyCheck = "safety_check"
    case summarize = "summarize"
    /// Domanda libera: il testo va in `custom_prompt`.
    case custom = "custom"

    var id: String { rawValue }

    /// Le scorciatoie dell'assistente su un ordine esistente (il prompt libero ha il suo campo).
    static let assistActions: [Self] = [.improveDescription, .generateSteps, .estimateDuration,
                                        .suggestParts, .safetyCheck, .summarize]

    /// Le azioni della bozza nel form di creazione; la prima è quella del pulsante.
    static let draftActions: [Self] = [.completeDraft, .improveDescription, .generateSteps, .estimateDuration]

    var title: String {
        switch self {
        case .completeDraft: String(localized: "Complete draft")
        case .improveDescription: String(localized: "Improve description")
        case .generateSteps: String(localized: "Generate steps")
        case .estimateDuration: String(localized: "Estimate duration")
        case .suggestParts: String(localized: "Parts & tools")
        case .safetyCheck: String(localized: "Safety check")
        case .summarize: String(localized: "Summarize")
        case .custom: String(localized: "Custom question")
        }
    }

    /// Cosa fa, in una riga: sotto il titolo nelle scorciatoie dell'assistente.
    var subtitle: String {
        switch self {
        case .completeDraft: String(localized: "Fill in the missing fields")
        case .improveDescription: String(localized: "Clearer, more complete text")
        case .generateSteps: String(localized: "A step-by-step procedure")
        case .estimateDuration: String(localized: "How long the job takes")
        case .suggestParts: String(localized: "What to bring on site")
        case .safetyCheck: String(localized: "Risks and precautions")
        case .summarize: String(localized: "The work order in brief")
        case .custom: String(localized: "Ask anything")
        }
    }

    var systemImage: String {
        switch self {
        case .completeDraft: "pencil.and.list.clipboard"
        case .improveDescription: "pencil.line"
        case .generateSteps: "list.number"
        case .estimateDuration: "timer"
        case .suggestParts: "wrench.and.screwdriver"
        case .safetyCheck: "exclamationmark.shield"
        case .summarize: "text.alignleft"
        case .custom: "bubble.left.and.text.bubble.right"
        }
    }
}

/// POST /v1/work-orders/{id}/ai-assist (WOAIAssistRequest). Si codifica in snake_case dalla chiamata.
nonisolated struct AdminWorkOrderAIAssistRequest: Encodable, Sendable {
    var action: String
    var customPrompt: String?
}

/// POST /v1/work-orders/ai-draft (WOAIDraftRequest): l'azione e quello che il form ha già.
nonisolated struct AdminWorkOrderAIDraftRequest: Encodable, Sendable {
    var action: String
    var title: String
    var description: String?
    var type: String?
    var category: String?
    var priority: String?
    var assetTag: String?
    var alarmCode: String?
    var zone: String?
    var notes: String?
}
