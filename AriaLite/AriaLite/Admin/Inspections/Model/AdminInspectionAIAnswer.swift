//
//  AdminInspectionAIAnswer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La risposta di ai-improve letta senza schema: l'OpenAPI non la descrive. Si cercano un testo (note),
//  un elenco di controlli proposti e, se non si riconosce nulla, il JSON grezzo, così l'utente vede comunque
//  cosa ha risposto il server. Le chiavi si cercano in cima e dentro gli oggetti che avvolgono la risposta.
//

import Foundation

nonisolated struct AdminInspectionAIAnswer: Equatable, Sendable {
    /// Testo proposto per le note dell'ispezione (o la spiegazione dell'AI).
    var text: String?
    /// Descrizioni dei controlli proposti, nell'ordine in cui arrivano.
    var items: [String] = []
    /// Il JSON grezzo, solo quando non si è riconosciuto nient'altro.
    var raw: String?

    var isEmpty: Bool { text == nil && items.isEmpty && raw == nil }

    init(json: AriaJSON) {
        var parser = Parser()
        parser.read(json.camelCased(), depth: 0)
        text = parser.text
        items = parser.items
        raw = (text == nil && items.isEmpty) ? Self.pretty(json) : nil
    }

    private static func pretty(_ json: AriaJSON) -> String? {
        if case .null = json { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(json) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        return text.isEmpty ? nil : text
    }

    /// Le proposte che non ripetono un controllo già presente (confronto senza maiuscole né accenti).
    func newItems(comparedTo existing: [AdminInspectionItem]) -> [String] {
        func key(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var seen = Set(existing.map { key($0.description) })
        return items.filter { seen.insert(key($0)).inserted }
    }

    // MARK: Lettura

    private nonisolated struct Parser {
        var text: String?
        var items: [String] = []

        static let textKeys = ["notes", "improvedNotes", "summary", "answer", "text", "content", "message",
                               "response", "output", "analysis", "explanation", "reply", "markdown", "suggestion"]
        static let itemKeys = ["items", "checklist", "checklistItems", "improvedItems", "suggestedItems",
                               "newItems", "tasks", "steps", "checks", "suggestions"]
        static let nestedKeys = ["inspection", "data", "result", "proposal", "proposed", "improved", "output",
                                 "response", "suggestions", "changes"]

        mutating func read(_ json: AriaJSON, depth: Int) {
            guard depth < 4 else { return }
            switch json {
            case .string(let string):
                if let inner = Self.embeddedJSON(string) {
                    read(inner, depth: depth + 1)
                } else if text == nil {
                    text = string.trimmingCharacters(in: .whitespacesAndNewlines).inspectionNilIfEmpty
                }
            case .array(let array):
                if items.isEmpty { items = array.compactMap(Self.itemText) }
            case .object(let object):
                if items.isEmpty {
                    for key in Self.itemKeys {
                        if let value = object[key], let list = Self.list(value), !list.isEmpty {
                            items = list
                            break
                        }
                    }
                }
                if text == nil {
                    for key in Self.textKeys {
                        guard let string = object[key]?.nonEmptyString else { continue }
                        if let inner = Self.embeddedJSON(string) { read(inner, depth: depth + 1) } else { text = string }
                        break
                    }
                }
                for key in Self.nestedKeys {
                    if let inner = object[key], inner.objectValue != nil { read(inner, depth: depth + 1) }
                }
            default:
                break
            }
        }

        /// Un elenco: array di testi o di oggetti, o un testo a righe.
        static func list(_ value: AriaJSON) -> [String]? {
            switch value {
            case .array(let array): array.compactMap(itemText)
            case .string(let string): embeddedJSON(string) == nil ? lines(string) : nil
            default: nil
            }
        }

        static func itemText(_ item: AriaJSON) -> String? {
            if let text = item.nonEmptyString { return text }
            guard let object = item.objectValue else { return nil }
            return ["description", "text", "title", "name", "check", "step", "content"]
                .lazy.compactMap { object[$0]?.nonEmptyString }.first
        }

        /// Righe di un testo, senza numeri o trattini in testa.
        static func lines(_ text: String) -> [String] {
            text.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces).replacing(/^(\d+[.)]\s*|[-•*]\s*)/, with: "") }
                .filter { !$0.isEmpty }
        }

        /// Il JSON dentro un testo (anche in un blocco ```json```), se il testo è solo quello.
        static func embeddedJSON(_ text: String) -> AriaJSON? {
            var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if body.hasPrefix("```") {
                body = body.replacing(/^```[a-zA-Z]*\s*/, with: "").replacing(/\s*```$/, with: "")
            }
            guard body.hasPrefix("{") || body.hasPrefix("["), body.hasSuffix("}") || body.hasSuffix("]"),
                  let json = try? JSONDecoder().decode(AriaJSON.self, from: Data(body.utf8)) else { return nil }
            return json.camelCased()
        }
    }
}

private nonisolated extension String {
    /// Il testo, o `nil` se è vuoto (nome prefissato: non si scontra con estensioni di altre sezioni).
    var inspectionNilIfEmpty: String? { isEmpty ? nil : self }
}
