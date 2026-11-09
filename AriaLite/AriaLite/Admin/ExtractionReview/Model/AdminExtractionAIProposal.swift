//
//  AdminExtractionAIProposal.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La risposta di ai-improve / ai-analyze letta senza schema (l'OpenAPI non la descrive): un testo da
//  mostrare e i nuovi valori dei campi modificabili dell'elemento, cercati col loro nome in cima o dentro
//  `improved`/`suggestions`/`result`/`data`… Se non si riconosce nulla resta il JSON grezzo.
//

import Foundation

nonisolated struct AdminExtractionAIProposal: Equatable, Sendable {
    /// Un campo che l'AI propone di cambiare.
    struct Change: Equatable, Sendable, Identifiable {
        let key: String
        let label: String
        let current: String
        let proposed: String
        var id: String { key }
    }

    var text: String?
    var changes: [Change]
    /// Il JSON grezzo, solo quando non si è riconosciuto nient'altro.
    var raw: String?

    var isEmpty: Bool { text == nil && changes.isEmpty && raw == nil }

    init(json: AriaJSON, fields: [AdminExtractionField]) {
        let json = json.camelCased()
        var objects: [[String: AriaJSON]] = []
        var texts: [String] = []
        Self.collect(json, depth: 0, objects: &objects, texts: &texts)

        changes = fields.compactMap { field in
            guard let value = Self.value(for: field, in: objects),
                  let proposed = Self.editorText(value, for: field),
                  !field.isUnchanged(proposed), field.wireValue(for: proposed) != nil else { return nil }
            return Change(key: field.key, label: field.label, current: field.value, proposed: proposed)
        }
        let proposedTexts = Set(changes.map(\.proposed))
        text = texts.first { !proposedTexts.contains($0) }
        raw = (text == nil && changes.isEmpty) ? Self.pretty(json) : nil
    }

    // MARK: Lettura

    private static let textKeys = ["answer", "text", "message", "summary", "analysis", "explanation", "reasoning",
                                   "content", "result", "response", "output", "recommendation", "recommendations", "notes"]
    private static let nestedKeys = ["improved", "suggestions", "suggestion", "proposal", "proposed", "changes", "fields",
                                     "updated", "result", "data", "output", "response", "analysis", "alarm", "asset",
                                     "plan", "maintenancePlan", "sparePart", "part", "item"]

    /// Gli oggetti dove cercare i campi (dal più esterno) e i testi da mostrare.
    private static func collect(_ json: AriaJSON, depth: Int, objects: inout [[String: AriaJSON]], texts: inout [String]) {
        guard depth < 4 else { return }
        switch json {
        case .string(let string):
            if let inner = embeddedJSON(string) {
                collect(inner, depth: depth + 1, objects: &objects, texts: &texts)
            } else if let trimmed = json.nonEmptyString {
                texts.append(trimmed)
            }
        case .object(let object):
            objects.append(object)
            for key in textKeys {
                guard let value = object[key] else { continue }
                if let string = value.nonEmptyString, embeddedJSON(string) == nil {
                    texts.append(string)
                } else if case .array = value {
                    let lines = AdminExtractionWire.lines(of: value)
                    if !lines.isEmpty { texts.append(lines.map { "- \($0)" }.joined(separator: "\n")) }
                }
            }
            for key in Set(textKeys + nestedKeys) {
                guard let value = object[key] else { continue }
                if value.objectValue != nil {
                    collect(value, depth: depth + 1, objects: &objects, texts: &texts)
                } else if let string = value.nonEmptyString, let inner = embeddedJSON(string) {
                    collect(inner, depth: depth + 1, objects: &objects, texts: &texts)
                }
            }
        default:
            break
        }
    }

    /// Il valore proposto per un campo: col suo nome o come `improvedX` / `suggestedX`. Vince il più interno
    /// (`improved.description` batte la `description` in cima, che spesso è l'originale).
    private static func value(for field: AdminExtractionField, in objects: [[String: AriaJSON]]) -> AriaJSON? {
        let base = field.camelKey
        let capitalized = base.prefix(1).uppercased() + base.dropFirst()
        let keys = ["improved\(capitalized)", "suggested\(capitalized)", "new\(capitalized)", base]
        for object in objects.reversed() {
            for key in keys {
                if let value = object[key], value != .null { return value }
            }
        }
        return nil
    }

    /// Il valore come testo dell'editor del campo.
    private static func editorText(_ value: AriaJSON, for field: AdminExtractionField) -> String? {
        switch field.editor {
        case .list:
            let lines = AdminExtractionWire.lines(of: value)
            return lines.isEmpty ? nil : lines.joined(separator: "\n")
        case .decimal, .integer:
            return value.doubleValue.map { AdminExtractionField.text($0) }
        case .choice(let choices):
            guard let text = value.nonEmptyString?.lowercased() else { return nil }
            return choices.first { $0.value.lowercased() == text || $0.label.lowercased() == text }?.value
        case .text, .multiline:
            return value.nonEmptyString
        }
    }

    /// Il JSON dentro un testo (anche in un blocco ```json```), se il testo è solo quello.
    private static func embeddedJSON(_ text: String) -> AriaJSON? {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("```") {
            body = body.replacing(/^```[a-zA-Z]*\s*/, with: "").replacing(/\s*```$/, with: "")
        }
        guard body.hasPrefix("{"), body.hasSuffix("}"),
              let json = try? JSONDecoder().decode(AriaJSON.self, from: Data(body.utf8)) else { return nil }
        return json.camelCased()
    }

    private static func pretty(_ json: AriaJSON) -> String? {
        if case .null = json { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(json) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        return text.isEmpty ? nil : text
    }
}
