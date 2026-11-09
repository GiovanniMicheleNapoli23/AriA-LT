//
//  AdminCraftedCompareModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una versione letta contro un'altra: la barra in alto (chi, quando, legenda, "vs originale", Ripristina)
//  e, per un artifact, il testo diviso in parole aggiunte e tolte e le tabelle riga per riga. Si calcola
//  una volta quando si apre il confronto, non a ogni disegno della vista.
//

import Foundation

/// Con cosa si confronta una versione.
nonisolated enum AdminCraftedCompareAgainst: Hashable, Sendable {
    case original
    case previous
}

/// La barra del confronto; la stessa per un artifact e per un report.
nonisolated struct AdminCraftedCompareHeader: Hashable, Sendable {
    let number: Int
    /// Chi e quando; per l'originale, "Originale di Aria".
    let byline: String
    let unchanged: Bool
    /// Si può scegliere fra originale e precedente (dalla v3 in su: la v2 differisce dall'originale e basta).
    let canPickAgainst: Bool
    let against: AdminCraftedCompareAgainst
    let previousLabel: String
    let canRestore: Bool

    init(number: Int, meta: AdminCraftedVersionMeta?, count: AdminCraftedChangeCount,
         against: AdminCraftedCompareAgainst, current: Int) {
        self.number = number
        byline = meta?.byline ?? String(localized: "Aria's original")
        unchanged = count.isEmpty
        canPickAgainst = number > 2
        self.against = against
        previousLabel = String(localized: "vs v\(number - 1)")
        canRestore = number != current
    }
}

nonisolated struct AdminCraftedCompareTable: Identifiable, Hashable, Sendable {
    let id: String
    let title: String?
    let columns: [AdminCraftedColumn]
    let rows: [AdminCraftedRowDiff]
}

/// Una risposta di Aria nel confronto: il suo testo a segmenti e le sue tabelle.
nonisolated struct AdminCraftedCompareBlock: Identifiable, Hashable, Sendable {
    let id: String
    let segments: [AdminCraftedTextDiff.Segment]?
    let tables: [AdminCraftedCompareTable]

    /// `next` segnato contro `base`, risposta per risposta.
    static func blocks(parts: [AdminCraftedEditablePart], base: AdminCraftedArtifactEdits,
                       next: AdminCraftedArtifactEdits) -> [AdminCraftedCompareBlock] {
        parts.map { part in
            AdminCraftedCompareBlock(
                id: part.messageId,
                segments: part.text.map { original in
                    AdminCraftedTextDiff.diff(before: base.texts[part.messageId] ?? original,
                                              after: next.texts[part.messageId] ?? original)
                },
                tables: part.tables.map { table in
                    AdminCraftedCompareTable(
                        id: table.artifactId, title: table.title, columns: table.columns,
                        rows: AdminCraftedRowDiff.diff(base: base.tables[table.artifactId] ?? table.originalRows,
                                                       next: next.tables[table.artifactId] ?? table.originalRows,
                                                       columns: table.columns)
                    )
                }
            )
        }
    }
}
