//
//  AdminCraftedVersionHistoryEntry.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una riga della cronologia versioni, già scritta in testo: numero, chi e quando, cosa aveva chiesto
//  Aria, quanto ha cambiato. Le costruisce chi ha le versioni (artifact o report) e le mostra
//  AdminCraftedVersionHistorySheet, uguale per tutti e due.
//

import Foundation

nonisolated struct AdminCraftedVersionHistoryEntry: Identifiable, Hashable, Sendable {
    let number: Int
    let label: String
    let isCurrent: Bool
    /// "Marco · 23 ott, 10:45".
    let byline: String
    /// Cosa si è chiesto ad Aria, se è una versione sua.
    let detail: String?
    let summary: String
    var id: Int { number }

    /// Dalla più nuova alla prima, fino all'originale di Aria. `metas` va dalla più vecchia alla più nuova;
    /// `changes(i)` dice quanto la versione `i` ha cambiato rispetto a quella prima (o all'originale per la prima).
    static func entries(metas: [AdminCraftedVersionMeta], current: Int, createdAt: Date,
                        changes: (Int) -> AdminCraftedChangeCount) -> [AdminCraftedVersionHistoryEntry] {
        var rows = Array(metas.enumerated()).reversed().map { index, meta in
            AdminCraftedVersionHistoryEntry(
                number: meta.number, label: AdminCraftedVersionMeta.label(meta.number), isCurrent: meta.number == current,
                byline: meta.byline, detail: meta.via.map { "“\($0.instruction)”" },
                summary: meta.kind == .restore
                    ? String(localized: "Restored v\(meta.restoredFrom ?? 1)")
                    : AdminCraftedVersionMeta.summary(of: changes(index))
            )
        }
        rows.append(AdminCraftedVersionHistoryEntry(
            number: 1, label: AdminCraftedVersionMeta.label(1), isCurrent: current == 1,
            byline: "Aria · \(AdminCraftedVersionMeta.when(createdAt))", detail: nil,
            summary: String(localized: "Aria's original")
        ))
        return rows
    }
}
