//
//  AdminCraftedAriaMapping.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Dal documento ai blocchi per Aria e dalle sue modifiche di nuovo al documento. Un artifact manda un
//  blocco di testo per ogni risposta (`t:<id messaggio>`) e uno per ogni tabella (`table:<id card>`); un
//  rapporto un blocco per paragrafo non vuoto (`p<indice>`). Le modifiche si stendono sopra la base della
//  richiesta — la versione attuale, o la proposta già sulla pagina per un seguito — come nella web.
//

import Foundation

nonisolated enum AdminCraftedAriaMapping {
    private static let textPrefix = "t:"
    private static let tablePrefix = "table:"
    private static let paragraphPrefix = "p"

    // MARK: Artifact

    /// I blocchi delle risposte scelte (`only` vuoto = tutte), così come si leggono sopra `base`.
    static func artifactBlocks(parts: [AdminCraftedEditablePart], base: AdminCraftedArtifactEdits,
                               only messageIds: Set<String>) -> [AdminCraftedAriaBlock] {
        let picked = messageIds.isEmpty ? parts : parts.filter { messageIds.contains($0.messageId) }
        return picked.flatMap { part -> [AdminCraftedAriaBlock] in
            var blocks: [AdminCraftedAriaBlock] = []
            if let original = part.text {
                blocks.append(.text(id: textPrefix + part.messageId, text: base.texts[part.messageId] ?? original))
            }
            for table in part.tables {
                blocks.append(.table(id: tablePrefix + table.artifactId, columns: table.columns,
                                     rows: base.tables[table.artifactId] ?? table.originalRows))
            }
            return blocks
        }
    }

    /// Le modifiche di Aria sopra `base`; `nil` se non cambiano niente rispetto a `base`.
    static func artifactEdits(_ changes: [AdminCraftedAriaChange], base: AdminCraftedArtifactEdits,
                              parts: [AdminCraftedEditablePart]) -> AdminCraftedArtifactEdits? {
        var next = AdminCraftedArtifactEdits(texts: base.texts, tables: base.tables)
        for change in changes {
            switch change {
            case .text(let id, let text):
                guard id.hasPrefix(textPrefix) else { continue }
                next.texts[String(id.dropFirst(textPrefix.count))] = text
            case .rows(let id, let rows):
                guard id.hasPrefix(tablePrefix) else { continue }
                next.tables[String(id.dropFirst(tablePrefix.count))] = rows.map {
                    AdminCraftedEditedRow(id: $0.id ?? AdminCraftedEditedRow.newID(), cells: $0.cells)
                }
            }
        }
        let edits = AdminCraftedEditing.normalized(next, parts: parts)
        return edits == AdminCraftedEditing.normalized(base, parts: parts) ? nil : edits
    }

    // MARK: Rapporto

    /// Un blocco per ogni paragrafo con del testo (gli indici scelti, o tutti); le celle delle tabelle sono già paragrafi.
    static func reportBlocks(texts: [String], only indices: Set<Int>) -> [AdminCraftedAriaBlock] {
        texts.indices.compactMap { index -> AdminCraftedAriaBlock? in
            guard indices.isEmpty || indices.contains(index),
                  !texts[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .text(id: paragraphPrefix + String(index), text: texts[index])
        }
    }

    /// I testi dei paragrafi con le modifiche di Aria; `nil` se nessun paragrafo cambia rispetto a `base`.
    /// Un paragrafo resta un paragrafo: il file non ha modo di riprendersi un a capo.
    static func reportTexts(_ changes: [AdminCraftedAriaChange], base: [String]) -> [String]? {
        var next = base
        for change in changes {
            guard case .text(let id, let text) = change, id.hasPrefix(paragraphPrefix),
                  let index = Int(id.dropFirst(paragraphPrefix.count)), next.indices.contains(index) else { continue }
            next[index] = singleParagraph(text)
        }
        return next == base ? nil : next
    }

    /// `text.replace(/\s*\n+\s*/g, " ")`: ogni a capo, con gli spazi intorno, diventa uno spazio.
    static func singleParagraph(_ text: String) -> String {
        guard text.contains(where: \.isNewline) else { return text }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
