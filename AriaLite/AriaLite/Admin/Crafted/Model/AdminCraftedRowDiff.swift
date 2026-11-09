//
//  AdminCraftedRowDiff.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le righe di una tabella confrontate fra due versioni (diffRows della web), riga per riga rispetto a
//  dove ognuna è nata: una riga tolta si vede barrata dov'era, non come tutte le successive cambiate.
//

import Foundation

/// Una colonna della tabella di Aria: `key` per le celle, `label` per l'intestazione.
nonisolated struct AdminCraftedColumn: Hashable, Sendable, Identifiable {
    let key: String
    let label: String
    var id: String { key }
}

nonisolated enum AdminCraftedRowDiff: Hashable, Sendable {
    /// Uguale, o con celle cambiate (`changed` = le chiavi delle colonne che differiscono).
    case row(cells: [String: AdminCraftedCell], before: [String: AdminCraftedCell], changed: Set<String>)
    case added(cells: [String: AdminCraftedCell])
    case removed(before: [String: AdminCraftedCell])

    /// Righe con almeno una cella diversa.
    var isChanged: Bool {
        if case .row(_, _, let changed) = self { return !changed.isEmpty }
        return false
    }

    static func diff(base: [AdminCraftedEditedRow], next: [AdminCraftedEditedRow], columns: [AdminCraftedColumn]) -> [AdminCraftedRowDiff] {
        let nextIDs = Set(next.map(\.id))
        var baseIndex: [String: Int] = [:]
        for (index, row) in base.enumerated() where baseIndex[row.id] == nil { baseIndex[row.id] = index }
        var out: [AdminCraftedRowDiff] = []
        var cursor = 0
        func removedUpTo(_ limit: Int) {
            while cursor < limit {
                if !nextIDs.contains(base[cursor].id) { out.append(.removed(before: base[cursor].cells)) }
                cursor += 1
            }
        }
        for row in next {
            guard let at = baseIndex[row.id] else {
                out.append(.added(cells: row.cells))
                continue
            }
            removedUpTo(at)
            cursor = max(cursor, at + 1)
            let before = base[at].cells
            let changed = Set(columns.filter { text(before[$0.key]) != text(row.cells[$0.key]) }.map(\.key))
            out.append(.row(cells: row.cells, before: before, changed: changed))
        }
        removedUpTo(base.count)
        return out
    }

    static func text(_ cell: AdminCraftedCell?) -> String { cell?.displayText ?? "" }
}
