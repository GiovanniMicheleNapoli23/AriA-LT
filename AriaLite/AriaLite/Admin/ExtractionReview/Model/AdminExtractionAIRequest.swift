//
//  AdminExtractionAIRequest.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni dell'AI sulla revisione (ai-improve di allarmi e piani, ai-analyze di asset e ricambi) e il
//  body comune. L'OpenAPI dice solo `action: string`: i valori qui sotto sono IPOTESI. Se il server ne
//  rifiuta uno (400/422) il dettaglio mostra il messaggio del server: basta correggere il `rawValue` qui.
//

import Foundation

nonisolated enum AdminExtractionAIAction: String, CaseIterable, Identifiable, Sendable {
    // Valori indovinati: da verificare col backend.
    case improve = "improve"
    case analyze = "analyze"
    case complete = "complete"
    case translate = "translate"
    /// Richiesta libera: il testo va in `custom_prompt`.
    case custom = "custom"

    var id: String { rawValue }

    /// Le azioni di un tipo: la principale secondo la rotta, poi completa e traduci (i ricambi non hanno lingua).
    static func actions(for kind: AdminExtractionKind) -> [Self] {
        switch kind {
        case .alarms, .maintenancePlans: [.improve, .complete, .translate]
        case .assets: [.analyze, .complete, .translate]
        case .spareParts: [.analyze, .complete]
        }
    }

    var title: String {
        switch self {
        case .improve: String(localized: "Improve")
        case .analyze: String(localized: "Analyze")
        case .complete: String(localized: "Fill in missing fields")
        case .translate: String(localized: "Translate to my language")
        case .custom: String(localized: "Custom request")
        }
    }

    var systemImage: String {
        switch self {
        case .improve: "wand.and.stars"
        case .analyze: "sparkle.magnifyingglass"
        case .complete: "text.badge.plus"
        case .translate: "character.bubble"
        case .custom: "bubble.left.and.text.bubble.right"
        }
    }
}

/// AlarmAIImproveRequest, AssetAIRequest, AIImproveRequest (piani) e SparePartAIRequest hanno in comune
/// `action`, `custom_prompt` e (tranne i ricambi) `language`. I `nil` non si scrivono.
nonisolated struct AdminExtractionAIRequest: Encodable, Sendable {
    var action: String
    var customPrompt: String?
    var language: String?
}
