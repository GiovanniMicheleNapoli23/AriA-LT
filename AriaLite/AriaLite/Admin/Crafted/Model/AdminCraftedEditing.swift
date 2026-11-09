//
//  AdminCraftedEditing.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Cosa si può modificare in una conversazione di Aria e come le modifiche si stendono sopra i suoi
//  messaggi (editableParts, applyEdits, normalizeEdits, countChanges di crafted-versions.ts): il testo
//  di ogni risposta e le tabelle. Un grafico o un ordine di lavoro si cambiano chiedendolo ad Aria.
//

import Foundation

/// Una tabella di Aria modificabile: le colonne restano le sue, le righe di partenza sono `o0`, `o1`…
nonisolated struct AdminCraftedEditableTable: Hashable, Sendable, Identifiable {
    let artifactId: String
    let title: String?
    let columns: [AdminCraftedColumn]
    let originalRows: [AdminCraftedEditedRow]
    var id: String { artifactId }
}

/// Una risposta di Aria con quello che ha di modificabile.
nonisolated struct AdminCraftedEditablePart: Hashable, Sendable, Identifiable {
    let messageId: String
    /// `nil` se la risposta non ha testo.
    let text: String?
    let tables: [AdminCraftedEditableTable]
    var id: String { messageId }
}

nonisolated enum AdminCraftedEditing {
    // MARK: Tabelle

    /// Una card `table` con colonne e righe: l'unica che si modifica a mano.
    static func table(of artifact: AriaArtifact) -> AdminCraftedEditableTable? {
        guard artifact.kind == "table",
              let columnList = artifact.data["columns"], case .array(let columnItems) = columnList,
              let rowList = artifact.data["rows"], case .array(let rowItems) = rowList else { return nil }
        let columns = columnItems.compactMap { item in
            item["key"]?.stringValue.map { AdminCraftedColumn(key: $0, label: item["label"]?.stringValue ?? $0) }
        }
        let rows = rowItems.enumerated().map { index, row in
            AdminCraftedEditedRow(id: "o\(index)", cells: (row.objectValue ?? [:]).mapValues { AdminCraftedCell(json: $0) })
        }
        return AdminCraftedEditableTable(artifactId: artifact.id, title: artifact.data["title"]?.nonEmptyString,
                                         columns: columns, originalRows: rows)
    }

    // MARK: Messaggi

    /// Ogni risposta con testo o tabelle, nell'ordine della conversazione.
    @MainActor
    static func editableParts(_ messages: [AriaAgentMessage]) -> [AdminCraftedEditablePart] {
        messages.filter { $0.role == .assistant }.compactMap { message in
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message.text
            let tables = message.artifacts.compactMap { table(of: $0) }
            return text == nil && tables.isEmpty ? nil : AdminCraftedEditablePart(messageId: message.id, text: text, tables: tables)
        }
    }

    /// La conversazione come la legge una versione: i messaggi di Aria con le modifiche sopra.
    @MainActor
    static func applyEdits(_ messages: [AriaAgentMessage], _ edits: AdminCraftedArtifactEdits) -> [AriaAgentMessage] {
        if edits.isEmpty { return messages }
        return messages.map { message in
            let text = edits.texts[message.id]
            let touchesTable = message.artifacts.contains { edits.tables[$0.id] != nil }
            if text == nil, !touchesTable { return message }
            var copy = message
            if let text { copy.text = text }
            if touchesTable {
                copy.artifacts = message.artifacts.map { artifact in
                    guard let rows = edits.tables[artifact.id] else { return artifact }
                    var data = artifact.data
                    data["rows"] = .array(rows.map { row in .object(row.cells.mapValues(\.json)) })
                    return AriaArtifact(id: artifact.id, kind: artifact.kind, role: artifact.role, data: data, source: artifact.source)
                }
            }
            return copy
        }
    }

    // MARK: Confronti

    /// Solo quello che differisce davvero dall'originale: un testo riscritto uguale, o una tabella rimessa cella per cella, non è una modifica.
    static func normalized(_ edits: AdminCraftedArtifactEdits, parts: [AdminCraftedEditablePart]) -> AdminCraftedArtifactEdits {
        var result = AdminCraftedArtifactEdits()
        for part in parts {
            if let edited = edits.texts[part.messageId], let original = part.text, edited != original {
                result.texts[part.messageId] = edited
            }
            for table in part.tables {
                if let rows = edits.tables[table.artifactId], !sameRows(table.originalRows, rows, columns: table.columns) {
                    result.tables[table.artifactId] = rows
                }
            }
        }
        return result
    }

    static func sameEdits(_ a: AdminCraftedArtifactEdits, _ b: AdminCraftedArtifactEdits) -> Bool { a == b }

    private static func sameRows(_ a: [AdminCraftedEditedRow], _ b: [AdminCraftedEditedRow], columns: [AdminCraftedColumn]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { x, y in
            x.id == y.id && columns.allSatisfy { AdminCraftedRowDiff.text(x.cells[$0.key]) == AdminCraftedRowDiff.text(y.cells[$0.key]) }
        }
    }

    /// Quanto `next` ha cambiato rispetto a `base`, per la sua riga nella cronologia.
    static func countChanges(parts: [AdminCraftedEditablePart], base: AdminCraftedArtifactEdits, next: AdminCraftedArtifactEdits) -> AdminCraftedChangeCount {
        var count = AdminCraftedChangeCount()
        for part in parts {
            if let original = part.text {
                let before = base.texts[part.messageId] ?? original
                let after = next.texts[part.messageId] ?? original
                count.add(AdminCraftedTextDiff.diff(before: before, after: after))
            }
            for table in part.tables {
                let before = base.tables[table.artifactId] ?? table.originalRows
                let after = next.tables[table.artifactId] ?? table.originalRows
                for row in AdminCraftedRowDiff.diff(base: before, next: after, columns: table.columns) {
                    switch row {
                    case .row(_, _, let changed): count.cells += changed.count
                    case .added, .removed: count.cells += table.columns.count
                    }
                }
            }
        }
        return count
    }

    // MARK: Versioni

    /// Le modifiche a cui rimanda un numero di versione: la 1 è l'originale.
    static func edits(of versions: [AdminCraftedArtifactVersion], number: Int) -> AdminCraftedArtifactEdits {
        versions.first { $0.number == number }?.edits ?? .none
    }

    /// Il numero della versione attuale; 1 senza versioni salvate.
    static func currentNumber(_ numbers: [Int]?) -> Int { numbers?.last ?? 1 }
}
