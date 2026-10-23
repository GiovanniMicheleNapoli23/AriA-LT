//
//  AdminCraftedAriaProposalParser.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Cosa Aria ha risposto, letto come modifiche (jsonIn e parseProposal di edit-with-aria.ts): l'oggetto
//  JSON nella risposta, con o senza recinto di codice e prosa intorno, e di questo si tiene solo quello che
//  combacia con il documento mandato — un blocco che esiste, del suo tipo, con celle solo nelle sue colonne.
//

import Foundation

nonisolated enum AdminCraftedAriaProposalParser {
    /// L'oggetto JSON della risposta: dentro un recinto ``` se c'è, altrimenti dalla prima `{` all'ultima `}`.
    static func jsonIn(_ text: String) -> AriaJSON? {
        let source = fenced(text) ?? text
        guard let start = source.firstIndex(of: "{"), let end = source.lastIndex(of: "}"), start < end else { return nil }
        return try? JSONDecoder().decode(AriaJSON.self, from: Data(source[start...end].utf8))
    }

    private static func fenced(_ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "```(?:json)?\\s*([\\s\\S]*?)```", options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    /// Le modifiche della risposta; `nil` se non è un oggetto con `changes` (né `needsWhole`).
    static func parse(_ text: String, blocks: [AdminCraftedAriaBlock]) -> AdminCraftedAriaAnswer? {
        guard let parsed = jsonIn(text), parsed.objectValue != nil else { return nil }
        if parsed["needsWhole"]?.boolValue == true { return AdminCraftedAriaAnswer(changes: [], note: nil, needsWhole: true) }
        guard case .array(let items)? = parsed["changes"] else { return nil }
        let byId = Dictionary(blocks.map { ($0.id, $0) }) { _, last in last }
        var changes: [AdminCraftedAriaChange] = []
        for raw in items {
            guard let id = string(raw["id"]), let block = byId[id] else { continue }
            switch block {
            case .text(_, let original):
                if let text = string(raw["text"]), text != original { changes.append(.text(id: id, text: text)) }
            case .table(_, let columns, let known):
                guard case .array(let rows)? = raw["rows"] else { continue }
                let knownIds = Set(known.map(\.id))
                changes.append(.rows(id: id, rows: rows.compactMap { row(from: $0, columns: columns, known: knownIds) }))
            }
        }
        let note = string(parsed["note"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AdminCraftedAriaAnswer(changes: changes, note: note?.isEmpty == false ? note : nil)
    }

    /// Una riga con le celle di ogni colonna (null dove non c'è niente) e l'id solo se è di una riga che esiste.
    private static func row(from raw: AriaJSON, columns: [AdminCraftedColumn], known: Set<String>) -> AdminCraftedAriaChange.Row? {
        guard let cells = raw["cells"]?.objectValue else { return nil }
        let id = string(raw["id"]).flatMap { known.contains($0) ? $0 : nil }
        var values: [String: AdminCraftedCell] = [:]
        for column in columns {
            switch cells[column.key] {
            case .string(let text)?: values[column.key] = .text(text)
            case .number(let number)?: values[column.key] = .number(number)
            default: values[column.key] = .empty
            }
        }
        return AdminCraftedAriaChange.Row(id: id, cells: values)
    }

    /// Una stringa vera: un numero o un booleano non valgono (typeof === "string").
    private static func string(_ json: AriaJSON?) -> String? {
        if case .string(let text)? = json { return text }
        return nil
    }
}
