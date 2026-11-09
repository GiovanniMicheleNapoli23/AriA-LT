//
//  AdminCraftedAriaPrompt.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Il testo che si manda ad Aria per modificare un documento (buildEditPrompt, buildReadPrompt e
//  blocksBody di edit-with-aria.ts): identico a quello della web, in inglese — è una consegna ad Aria,
//  non testo dell'interfaccia. Il documento va come blocchi numerati fra <<<id tipo e >>>.
//

import Foundation

nonisolated enum AdminCraftedAriaPrompt {
    /// Quale parte di un documento lungo è questa; `whole` per l'ultima di una lettura intera.
    nonisolated struct Part: Hashable, Sendable {
        var n: Int
        var total: Int
        var whole = false
    }

    private static let quotes = "\"\"\""

    /// `focus` è il passaggio che l'operatore ha scelto, se uno: l'istruzione parla di quello.
    static func edit(instruction: String, blocks: [AdminCraftedAriaBlock], focus: String? = nil, part: Part? = nil) -> String {
        var lines = [
            "Edit the document below by applying this instruction, and nothing else:",
            quotes + instruction.trimmingCharacters(in: .whitespacesAndNewlines) + quotes,
        ]
        if let focus = focus?.trimmingCharacters(in: .whitespacesAndNewlines), !focus.isEmpty {
            lines += ["", "The operator selected this passage, and the instruction is about it:", quotes + focus + quotes]
        }
        lines += [
            "",
            "The document is a list of blocks, each between <<<id kind and >>>. A text block is a paragraph or a",
            "Markdown section; a table block is JSON with its columns and its rows.",
        ]
        if let part, part.total > 1 { lines += partLines(part) }
        lines += [
            "",
            "Reply with ONE JSON object and nothing else — no prose around it, no code fence, no tools:",
            #"{"changes":[{"id":"<text block id>","text":"<its complete new text>"},{"id":"<table block id>","rows":[{"id":"<row id, or new>","cells":{"<column key>":"<value>"}}]}],"note":"<one short sentence on what you changed>"}"#,
            "",
            "Rules:",
            "- Include only the blocks you change, each with its complete new content.",
            #"- A table you change is given whole: every row, in order, keeping each row's id; a row you add has id "new"; a row you leave out is removed."#,
            "- A text block stays one block: keep its Markdown if it has any, and keep a paragraph a single paragraph.",
            "- Write in the document's own language, and the note too.",
            "- Keep the facts. Never invent measurements, codes, dates, names or steps that are not in the document or the instruction.",
            #"- If the instruction cannot be applied to this document at all, reply {"changes":[],"note":"<why, in one sentence>"}."#,
            "",
            blocksBody(blocks),
        ]
        return lines.joined(separator: "\n")
    }

    private static func partLines(_ part: Part) -> [String] {
        if part.whole {
            return [
                "The document is long, so it came in \(part.total) parts: parts 1 to \(part.total - 1) are in your previous messages in",
                "this conversation, and this is the last one. Apply the instruction to the whole document, reading all the",
                "parts together: a change may be to a block of any part.",
            ]
        }
        return [
            "This is part \(part.n) of \(part.total) of the document, sent in parts because it is long. Apply the instruction to",
            "the blocks of this part as part of the whole document, and reply for this part only. Whatever applies to each",
            "block on its own (tone, style, corrections, translation, shortening, renaming, removing a passage) is done",
            "here. Only when the instruction cannot be carried out without reading the other parts as well (a summary or",
            "a conclusion of the whole document, reordering or merging across parts, removing what repeats elsewhere),",
            #"reply {"needsWhole":true} and nothing else."#,
        ]
    }

    /// Una parte di un documento lungo mandata prima dell'istruzione, perché Aria la legga e basta: l'istruzione arriva con l'ultima.
    static func read(blocks: [AdminCraftedAriaBlock], part: Part) -> String {
        [
            "I am sending you a document to edit, in \(part.total) parts because it is long. This is part \(part.n): read it and",
            "do nothing else with it yet — no edits, no tools, no questions. The instruction comes with the last part.",
            "Reply with just: OK \(part.n)/\(part.total)",
            "",
            blocksBody(blocks),
        ].joined(separator: "\n")
    }

    static func blocksBody(_ blocks: [AdminCraftedAriaBlock]) -> String {
        blocks.map { block in
            switch block {
            case .text(let id, let text): "<<<\(id) text\n\(text)\n>>>"
            case .table(let id, let columns, let rows): "<<<\(id) table\n\(tableJSON(columns: columns, rows: rows))\n>>>"
            }
        }.joined(separator: "\n\n")
    }

    // MARK: Tabelle

    private nonisolated struct TablePayload: Encodable, Sendable {
        nonisolated struct Column: Encodable, Sendable {
            let key: String
            let label: String
        }

        let columns: [Column]
        let rows: [AdminCraftedEditedRow]
    }

    /// `{"columns":[{key,label}],"rows":[{id,cells}]}`: compatto, con le chiavi in ordine fisso.
    static func tableJSON(columns: [AdminCraftedColumn], rows: [AdminCraftedEditedRow]) -> String {
        let payload = TablePayload(columns: columns.map { .init(key: $0.key, label: $0.label) }, rows: rows)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
