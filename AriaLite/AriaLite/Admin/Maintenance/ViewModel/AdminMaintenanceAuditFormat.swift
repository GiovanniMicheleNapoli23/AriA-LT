//
//  AdminMaintenanceAuditFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si scrive una voce dello storico di un piano: azione, icona, nome del campo e valori letti
//  (date leggibili, sì/no, elenchi su una riga).
//

import Foundation

enum AdminMaintenanceAuditFormat {
    static func actionLabel(_ action: String?) -> String {
        switch action?.lowercased() {
        case "create", "created": String(localized: "Created")
        case "update", "updated": String(localized: "Updated")
        case "delete", "deleted": String(localized: "Deleted")
        case "soft_delete": String(localized: "Archived")
        case "restore", "restored": String(localized: "Restored")
        case let other?: fieldLabel(other)
        case nil: String(localized: "Changed")
        }
    }

    static func icon(_ action: String?) -> String {
        switch action?.lowercased() {
        case "create", "created": "plus.circle.fill"
        case "delete", "deleted": "trash.circle.fill"
        case "soft_delete": "archivebox.circle.fill"
        case "restore", "restored": "arrow.uturn.backward.circle.fill"
        default: "pencil.circle.fill"
        }
    }

    /// "next_due_at" o "nextDueAt" → "Next due at".
    static func fieldLabel(_ field: String) -> String {
        var words: [String] = []
        var current = ""
        for character in field {
            if character == "_" || character == "-" || character == " " {
                if !current.isEmpty { words.append(current) }
                current = ""
            } else if character.isUppercase, !current.isEmpty {
                words.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { words.append(current) }
        let text = words.joined(separator: " ").lowercased()
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Testo breve di un valore. `nil` se vuoto.
    static func valueLabel(_ value: AriaJSON) -> String? {
        switch value {
        case .null: return nil
        case .bool(let flag): return flag ? String(localized: "Yes") : String(localized: "No")
        case .string(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.count >= 10, trimmed.contains("-"), trimmed.contains("T"), let date = AriaWireDate.parse(trimmed) {
                return date.formatted(date: .abbreviated, time: .shortened)
            }
            return trimmed
        case .number: return value.stringValue
        case .array(let items):
            // Passi e ricambi: elementi di testo su una riga, altrimenti JSON compatto.
            let texts = items.compactMap(\.nonEmptyString)
            if items.isEmpty { return nil }
            return texts.count == items.count ? texts.joined(separator: ", ") : value.compactDescription
        case .object: return value.compactDescription
        }
    }
}
