//
//  AdminCraftedReportEditing.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le modifiche a un rapporto, blocco per blocco (textsFor, editsFrom, countReportChanges di
//  report-versions.ts). Una modifica si stende solo sul blocco il cui testo è ancora quello che
//  sostituiva: se il backend scrivesse il rapporto diverso, quella che non combacia più si lascia
//  fuori invece di finire sul paragrafo sbagliato.
//

import Foundation

nonisolated enum AdminCraftedReportEditing {
    /// A quali versioni appartiene una resa: il rapporto e la lingua in cui si è letto.
    static func key(sessionId: String, episode: Int, locale: String?) -> String {
        "\(sessionId):\(episode):\(locale ?? "session")"
    }

    /// Il testo di ogni blocco in una versione: la sua modifica dove ancora combacia, il testo del rapporto altrove.
    static func textsFor(_ originals: [String], _ edits: AdminCraftedReportEdits) -> [String] {
        originals.enumerated().map { index, text in
            if let edit = edits.blocks[index], edit.before == text { return edit.after }
            return text
        }
    }

    /// Le modifiche che portano il testo del rapporto a `texts`.
    static func editsFrom(_ originals: [String], _ texts: [String]) -> AdminCraftedReportEdits {
        var blocks: [Int: AdminCraftedReportBlockEdit] = [:]
        for (index, before) in originals.enumerated() where index < texts.count && texts[index] != before {
            blocks[index] = AdminCraftedReportBlockEdit(before: before, after: texts[index])
        }
        return AdminCraftedReportEdits(blocks: blocks)
    }

    static func sameEdits(_ originals: [String], _ a: AdminCraftedReportEdits, _ b: AdminCraftedReportEdits) -> Bool {
        textsFor(originals, a) == textsFor(originals, b)
    }

    static func countChanges(_ originals: [String], base: AdminCraftedReportEdits, next: AdminCraftedReportEdits) -> AdminCraftedChangeCount {
        let before = textsFor(originals, base)
        let after = textsFor(originals, next)
        var count = AdminCraftedChangeCount()
        for (index, text) in before.enumerated() where text != after[index] {
            count.add(AdminCraftedTextDiff.diff(before: text, after: after[index]))
        }
        return count
    }

    /// Le modifiche che un numero di versione rappresenta: la 1 è il rapporto originale.
    static func edits(of versions: [AdminCraftedReportVersion], number: Int) -> AdminCraftedReportEdits {
        versions.first { $0.number == number }?.edits ?? .none
    }
}
