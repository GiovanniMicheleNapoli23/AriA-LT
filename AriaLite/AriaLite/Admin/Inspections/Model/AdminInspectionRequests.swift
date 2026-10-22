//
//  AdminInspectionRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Body delle scritture sulle ispezioni: creazione (InspectionCreate), item (InspectionItem e
//  ChecklistItemUpdate) e AI (InspectionAIRequest). Si codificano in snake_case dalla chiamata; le date sono
//  già stringhe ISO-8601 perché l'encoder comune scriverebbe un numero.
//

import Foundation

/// Un item dentro un body di creazione o modifica (InspectionItem): l'`id` è obbligatorio, anche per i nuovi.
nonisolated struct AdminInspectionItemBody: Encodable, Sendable {
    var id: String
    var order: Int
    var description: String
    var isChecked: Bool
    var notes: String?

    /// Lo stesso item come valore JSON per una PATCH (chiavi già in snake_case).
    var json: AriaJSON {
        var fields: [String: AriaJSON] = [
            "id": .string(id), "order": .number(Double(order)),
            "description": .string(description), "is_checked": .bool(isChecked)
        ]
        if let notes { fields["notes"] = .string(notes) }
        return .object(fields)
    }
}

/// POST /v1/inspections. I campi `nil` non si mandano: valgono i default del server.
nonisolated struct AdminInspectionCreate: Encodable, Sendable {
    var title: String
    var plantId: String
    var assetTag: String?
    var zone: String?
    var assignedTo: String?
    var notes: String?
    var dueDate: String?
    var items: [AdminInspectionItemBody]
}

/// PATCH /v1/inspections/{id}/items/{item_id} (ChecklistItemUpdate). Un campo `nil` non si manda.
/// Una nota svuotata va come testo vuoto: un `null` potrebbe voler dire "non cambiare".
nonisolated struct AdminInspectionItemChange: Encodable, Sendable {
    var isChecked: Bool?
    var notes: String?
}

/// Cosa chiedere all'AI. L'OpenAPI dice solo `action: string`: i valori sono IPOTESI da verificare dal vivo.
/// Se il server ne rifiuta uno (400/422) il motivo si mostra nel foglio: basta correggere il `rawValue`.
nonisolated enum AdminInspectionAIAction: String, CaseIterable, Identifiable, Sendable {
    case improve = "improve"
    case addMissing = "add_missing"
    case custom = "custom"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .improve: String(localized: "Improve checklist")
        case .addMissing: String(localized: "Add missing checks")
        case .custom: String(localized: "Custom request")
        }
    }

    var subtitle: String {
        switch self {
        case .improve: String(localized: "Clearer wording and a better order")
        case .addMissing: String(localized: "Checks the list doesn't cover yet")
        case .custom: String(localized: "Tell the assistant what you need")
        }
    }

    var systemImage: String {
        switch self {
        case .improve: "sparkles"
        case .addMissing: "text.badge.plus"
        case .custom: "bubble.left.and.text.bubble.right"
        }
    }
}

/// POST /v1/inspections/{id}/ai-improve (InspectionAIRequest).
nonisolated struct AdminInspectionAIRequest: Encodable, Sendable {
    var action: String
    var language: String?
    var customPrompt: String?
}
