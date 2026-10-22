//
//  AdminCraftedRender.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si legge la risposta di POST …/saved-widgets/{id}/render, che lo schema non descrive: si cerca
//  una card (`kind` + `data`, anche dentro `artifact`/`artifacts`/`result`), altrimenti si tiene il JSON
//  per mostrarlo come contenuto strutturato.
//

import Foundation

nonisolated enum AdminCraftedRender: Sendable, Equatable {
    /// Una card che AriaArtifactView sa disegnare.
    case artifact(AriaArtifact)
    /// Dati senza una card conosciuta: righe "chiave: valore" e tabelle semplici.
    case structured(AriaJSON)
    case empty

    static func read(_ json: AriaJSON, widget: AdminCraftedWidget) -> AdminCraftedRender {
        if let artifact = artifact(in: json, widget: widget, depth: 0) {
            return AdminCraftedKind.drawable.contains(artifact.kind) ? .artifact(artifact) : .structured(.object(artifact.data))
        }
        switch json {
        case .null: return .empty
        case .array(let items) where items.isEmpty: return .empty
        case .object(let object) where object.isEmpty: return .empty
        default: return .structured(json)
        }
    }

    /// Cerca la card al massimo due livelli sotto: `{artifact: …}`, `{artifacts: [ … ]}`, `{result: …}`.
    private static func artifact(in json: AriaJSON, widget: AdminCraftedWidget, depth: Int) -> AriaArtifact? {
        guard depth <= 2 else { return nil }
        switch json {
        case .array(let items):
            // Una lista di oggetti con le stesse chiavi è una tabella.
            let rows = items.compactMap(\.objectValue)
            guard !rows.isEmpty, rows.count == items.count else { return nil }
            // Una lista di card: vale la prima.
            if rows[0]["kind"] != nil, rows[0]["data"] != nil { return artifact(in: items[0], widget: widget, depth: depth + 1) }
            return make(kind: "table", data: table(rows), widget: widget)
        case .object(let object):
            for key in ["artifact", "widget", "result", "output"] {
                if let nested = object[key], let found = artifact(in: nested, widget: widget, depth: depth + 1) { return found }
            }
            if let list = object["artifacts"]?.arrayValue, let first = list.first,
               let found = artifact(in: first, widget: widget, depth: depth + 1) {
                return found
            }
            if let data = object["data"]?.objectValue {
                return make(kind: object["kind"]?.nonEmptyString ?? widget.kind, data: data, widget: widget)
            }
            // I campi della card direttamente in cima (columns/rows, series, kpis…): è la card del widget.
            let cardKeys: Set<String> = ["columns", "rows", "series", "kpis", "items", "moves", "candidates", "alarms", "widgets"]
            if !cardKeys.isDisjoint(with: object.keys) {
                return make(kind: object["kind"]?.nonEmptyString ?? widget.kind, data: object, widget: widget)
            }
            return nil
        default:
            return nil
        }
    }

    private static func make(kind: String, data: [String: AriaJSON], widget: AdminCraftedWidget) -> AriaArtifact {
        AriaArtifact(id: widget.id, kind: kind, role: "deliverable", data: data,
                     source: .init(toolName: widget.toolName, toolArgs: widget.toolArgs))
    }

    /// Righe libere → `columns` + `rows` come le tabelle della chat (colonne nell'ordine della prima riga).
    private static func table(_ rows: [[String: AriaJSON]]) -> [String: AriaJSON] {
        var keys: [String] = []
        for row in rows { for key in row.keys.sorted() where !keys.contains(key) { keys.append(key) } }
        let columns = keys.map { AriaJSON.object(["key": .string($0), "label": .string($0.replacingOccurrences(of: "_", with: " "))]) }
        return ["columns": .array(columns), "rows": .array(rows.map { .object($0) })]
    }
}
