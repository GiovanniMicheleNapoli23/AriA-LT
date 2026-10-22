//
//  AdminAuditLogText.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I testi dello storico: il verbo di ogni azione, il nome di ogni tipo di oggetto, i valori dei campi e le date.
//  Le azioni e i tipi che il server non conosce si mostrano come arrivano, con le parole separate e in minuscolo.
//

import Foundation

nonisolated enum AdminAuditLogText {
    // MARK: Azioni

    /// Il colore e l'icona si scelgono dall'azione; un'azione sconosciuta è "altro".
    static func tone(_ action: String?) -> AdminAuditLogTone {
        switch action?.lowercased() {
        case "create", "created": .added
        case "delete", "deleted", "soft_delete", "archive", "archived": .removed
        case "update", "updated", "restore", "restored": .changed
        default: .neutral
        }
    }

    static func icon(_ action: String?) -> String {
        switch action?.lowercased() {
        case "create", "created": "plus.circle.fill"
        case "delete", "deleted": "trash.circle.fill"
        case "soft_delete", "archive", "archived": "archivebox.circle.fill"
        case "restore", "restored": "arrow.uturn.backward.circle.fill"
        case "update", "updated": "pencil.circle.fill"
        default: "circle.fill"
        }
    }

    /// Il nome dell'azione per i menu e i filtri.
    static func actionLabel(_ action: String?) -> String {
        switch action?.lowercased() {
        case "create", "created": String(localized: "Created")
        case "update", "updated": String(localized: "Updated")
        case "delete", "deleted": String(localized: "Deleted")
        case "soft_delete": String(localized: "Archived")
        case "restore", "restored": String(localized: "Restored")
        case let other?: humanize(other)
        case nil: String(localized: "Changed")
        }
    }

    /// "Marco ha aggiornato Ordine di lavoro “Pompa 3”": chi, che cosa ha fatto, su che cosa.
    static func sentence(actor: String, action: String?, entity: String) -> String {
        switch action?.lowercased() {
        case "create", "created": String(localized: "\(actor) created \(entity)")
        case "update", "updated": String(localized: "\(actor) updated \(entity)")
        case "delete", "deleted": String(localized: "\(actor) deleted \(entity)")
        case "soft_delete", "archive", "archived": String(localized: "\(actor) archived \(entity)")
        case "restore", "restored": String(localized: "\(actor) restored \(entity)")
        default: String(localized: "\(actor) changed \(entity)")
        }
    }

    // MARK: Oggetti

    /// Il nome di un tipo di oggetto; i tipi che non conosco si leggono dal nome tecnico.
    static func entityTypeLabel(_ type: String?) -> String {
        switch type?.lowercased() {
        case "work_order": String(localized: "Work order")
        case "maintenance_plan": String(localized: "Maintenance plan")
        case "asset": String(localized: "Asset")
        case "vendor": String(localized: "Vendor")
        case "purchase_order": String(localized: "Purchase order")
        case "spare_part": String(localized: "Spare part")
        case "memory_fact": String(localized: "Memory fact")
        case "document": String(localized: "Document")
        case "team": String(localized: "Team")
        case let other?: humanize(other)
        case nil: String(localized: "Item")
        }
    }

    /// "Ordine di lavoro “Pompa 3”", o solo il tipo se non c'è un nome.
    static func entity(type: String?, name: String?) -> String {
        let label = entityTypeLabel(type)
        guard let name, !name.isEmpty else { return label }
        return "\(label) “\(name)”"
    }

    // MARK: Campi

    /// "assigned_to" o "assignedTo" → "Assigned to".
    static func humanize(_ field: String) -> String {
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

    /// Il testo breve di un valore: date leggibili, sì/no, JSON compatto per il resto. `nil` se è vuoto.
    static func valueText(_ value: AriaJSON?) -> String? {
        switch value {
        case nil, .null?: return nil
        case .bool(let flag)?: return flag ? String(localized: "Yes") : String(localized: "No")
        case .string(let text)?:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if trimmed.contains("T"), trimmed.contains("-"), let date = AriaDate.parse(trimmed) {
                return date.formatted(date: .abbreviated, time: .shortened)
            }
            return trimmed
        case .number?: return value?.stringValue
        case .array(let items)?: return items.isEmpty ? nil : value?.compactDescription
        case .object(let fields)?: return fields.isEmpty ? nil : value?.compactDescription
        }
    }

    // MARK: Date

    /// "5 min fa" nell'ultima settimana, poi la data.
    static func relative(_ date: Date) -> String {
        if abs(date.timeIntervalSinceNow) < 7 * 24 * 3600 {
            return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Il titolo del gruppo di un giorno.
    static func dayTitle(_ day: Date?) -> String {
        guard let day else { return String(localized: "No date") }
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return day.formatted(date: .long, time: .omitted)
    }
}
