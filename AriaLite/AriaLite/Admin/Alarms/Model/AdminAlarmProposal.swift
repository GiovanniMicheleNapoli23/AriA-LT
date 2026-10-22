//
//  AdminAlarmProposal.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La risposta di ai-improve letta senza schema (l'OpenAPI non la descrive): i nuovi valori dei campi
//  dell'allarme, cercati col loro nome in cima o dentro `improved`/`suggestions`/`result`…, più un testo
//  libero. Se non si riconosce nulla resta il JSON grezzo. Si propongono solo i campi diversi dagli attuali.
//

import Foundation

nonisolated struct AdminAlarmProposal: Equatable, Sendable {
    /// Un campo che l'AI propone di cambiare.
    struct Change: Equatable, Sendable, Identifiable {
        let field: AdminAlarmField
        /// Righe del nuovo valore (un testo solo = una riga).
        let proposed: [String]
        /// Righe del valore attuale, per il confronto.
        let current: [String]
        var id: String { field.id }
    }

    var changes: [Change]
    var text: String?
    /// Il JSON grezzo, solo se non si è riconosciuto nient'altro.
    var raw: String?

    var isEmpty: Bool { changes.isEmpty && text == nil && raw == nil }

    init(json: AriaJSON, alarm: AdminAlarm) {
        var objects: [[String: AriaJSON]] = []
        var texts: [String] = []
        Self.collect(json.camelCased(), depth: 0, objects: &objects, texts: &texts)
        changes = AdminAlarmField.allCases.compactMap { field in
            guard let value = Self.value(for: field, in: objects) else { return nil }
            let proposed = field.isList ? Self.lines(of: value) : (value.nonEmptyString.map { [$0] } ?? [])
            let current = Self.currentLines(of: field, in: alarm)
            guard !proposed.isEmpty, proposed != current else { return nil }
            return Change(field: field, proposed: proposed, current: current)
        }
        let proposedTexts = Set(changes.flatMap(\.proposed))
        text = texts.first { !proposedTexts.contains($0) }
        raw = (text == nil && changes.isEmpty) ? Self.pretty(json) : nil
    }

    /// Le righe dell'allarme per un campo.
    static func currentLines(of field: AdminAlarmField, in alarm: AdminAlarm) -> [String] {
        switch field {
        case .description: alarm.description.isEmpty ? [] : [alarm.description]
        case .category: alarm.category.map { [$0] } ?? []
        case .zone: alarm.zone.map { [$0] } ?? []
        case .hmiPage: alarm.hmiPage.map { [$0] } ?? []
        case .typicalCauses: alarm.typicalCauses
        case .resolutionSteps: alarm.resolutionSteps
        }
    }

    // MARK: Lettura

    private static let textKeys = ["answer", "text", "message", "summary", "explanation", "reasoning", "notes"]
    private static let nestedKeys = ["improved", "suggestions", "suggestion", "proposal", "proposed", "changes",
                                     "fields", "updated", "result", "data", "output", "response", "alarm"]

    /// Gli oggetti dove cercare i campi (dal più esterno) e i testi da mostrare.
    private static func collect(_ json: AriaJSON, depth: Int,
                                objects: inout [[String: AriaJSON]], texts: inout [String]) {
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
                if let string = object[key]?.nonEmptyString, embeddedJSON(string) == nil { texts.append(string) }
            }
            for key in nestedKeys + textKeys {
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
    private static func value(for field: AdminAlarmField, in objects: [[String: AriaJSON]]) -> AriaJSON? {
        let keys = field.responseKeys.flatMap { base -> [String] in
            let capitalized = base.prefix(1).uppercased() + base.dropFirst()
            return ["improved\(capitalized)", "suggested\(capitalized)", "new\(capitalized)", base]
        }
        for object in objects.reversed() {
            for key in keys {
                if let value = object[key], value != .null { return value }
            }
        }
        return nil
    }

    /// Le righe di un elenco: un array di testi o di oggetti, o un testo con una riga per voce.
    static func lines(of value: AriaJSON) -> [String] {
        switch value {
        case .array(let items):
            return items.compactMap { item in
                if let text = item.nonEmptyString { return text }
                return ["text", "description", "step", "action", "cause", "title"].lazy
                    .compactMap { item[$0]?.nonEmptyString }.first
            }
        case .string(let string):
            return string.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces).replacing(/^(\d+[.)]|[-•*])\s*/, with: "") }
                .filter { !$0.isEmpty }
        default:
            return []
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
