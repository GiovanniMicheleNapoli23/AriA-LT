//
//  AriaMarkdown.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il markdown delle risposte di Aria diviso in blocchi (titoli, elenchi, tabelle, codice, citazioni)
//  e il testo in linea come AttributedString. I risultati si ricordano: le viste rileggono lo stesso
//  testo a ogni pezzo in streaming.
//

import Foundation

enum AriaMarkdown {
    struct ListItem {
        let marker: String
        let text: String
        let depth: Int

        var isNumbered: Bool { marker.first?.isNumber == true }
    }

    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case list([ListItem])
        case quote(String)
        case code(String)
        case table([String], [[String]])
        case rule

        var isHeading: Bool { if case .heading = self { true } else { false } }
    }

    /// I risultati si ricordano: le viste rileggono lo stesso testo a ogni valutazione (a ogni pezzo di una
    /// risposta in streaming, per tutti i messaggi della chat) e il parsing costa millisecondi.
    private final class Cached<Value> {
        let value: Value
        init(_ value: Value) { self.value = value }
    }

    private static let inlineCache = makeCache(Cached<AttributedString>.self, limit: 2000)
    private static let blocksCache = makeCache(Cached<[Block]>.self, limit: 200)

    private static func makeCache<Value: AnyObject>(_ type: Value.Type, limit: Int) -> NSCache<NSString, Value> {
        let cache = NSCache<NSString, Value>()
        cache.countLimit = limit
        return cache
    }

    // MARK: - Testo in linea

    /// Un testo che cresce (un paragrafo in streaming) e il suo ultimo risultato. Ogni pezzo nuovo è un testo mai visto:
    /// nella cache principale ne entrerebbe uno a ogni tick, cacciando i messaggi già finiti. Qui ne resta uno solo
    /// per testo che cresce (se ne tengono pochi: una risposta alla volta, più eventuali code).
    private struct GrowingInline {
        var text: String
        var value: AttributedString
    }

    private static var growingInline: [GrowingInline] = []
    private static let growingInlineLimit = 4

    static func inline(_ text: String) -> AttributedString {
        let key = text as NSString
        if let hit = inlineCache.object(forKey: key) { return hit.value }
        // Lo stesso testo di prima, che cresceva: ora si ripete, quindi è fermo (risposta finita) e merita la cache vera.
        if let i = growingInline.firstIndex(where: { sameBytes($0.text, text) }) {
            let value = growingInline[i].value
            inlineCache.setObject(Cached(value), forKey: key)
            return value
        }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let parsed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        if !text.isEmpty, let i = growingInline.firstIndex(where: { !$0.text.isEmpty && startsWith(text, $0.text) }) {
            // Continua un testo già visto: sostituisce il pezzo precedente, la cache principale non si tocca.
            growingInline[i] = GrowingInline(text: text, value: parsed)
        } else {
            inlineCache.setObject(Cached(parsed), forKey: key)
            growingInline.append(GrowingInline(text: text, value: parsed))
            if growingInline.count > growingInlineLimit { growingInline.removeFirst() }
        }
        return parsed
    }

    // MARK: - Blocchi

    /// Un testo a blocchi che cresce. Il parsing è a righe e a ogni riga vuota fuori da un blocco di codice lo stato si
    /// azzera (paragrafo e elenco chiusi): quello che sta prima dell'ultima riga vuota non cambia più, qualunque cosa
    /// arrivi dopo. Si tengono i blocchi di quella parte stabile e a ogni pezzo si rileggono solo le righe dopo.
    private struct GrowingBlocks {
        /// Il testo (con i fine riga normalizzati) fino a una riga vuota compresa, `\n` finale incluso.
        var stableText: String
        var stableBlocks: [Block]
        /// L'ultimo testo ricevuto e il suo risultato, per chi lo rilegge identico.
        var lastText: String
        var lastBlocks: [Block]
    }

    private static var growingBlocks: [GrowingBlocks] = []
    private static let growingBlocksLimit = 6

    static func blocks(_ text: String) -> [Block] {
        let key = text as NSString
        if let hit = blocksCache.object(forKey: key) { return hit.value }

        // Lo stesso testo di prima, riletto: è fermo, passa nella cache vera.
        if let i = growingBlocks.firstIndex(where: { sameBytes($0.lastText, text) }) {
            let blocks = growingBlocks[i].lastBlocks
            blocksCache.setObject(Cached(blocks), forKey: key)
            return blocks
        }

        let normalized = normalizedNewlines(text)
        // La parte stabile più lunga che questo testo ancora comincia con.
        var best: Int?
        for (i, entry) in growingBlocks.enumerated() where startsWith(normalized, entry.stableText) {
            if best == nil || entry.stableText.utf8.count > growingBlocks[best!].stableText.utf8.count { best = i }
        }
        guard let best else {
            // Un testo nuovo: si legge tutto, come sempre, e si prepara per il prossimo pezzo.
            let empty = GrowingBlocks(stableText: "", stableBlocks: [], lastText: text, lastBlocks: [])
            let (entry, blocks) = parseGrowing(normalized, from: empty, raw: text)
            blocksCache.setObject(Cached(blocks), forKey: key)
            remember(entry)
            return blocks
        }
        let previous = growingBlocks[best]
        let continues = startsWith(text, previous.lastText)
        let (entry, blocks) = parseGrowing(normalized, from: previous, raw: text)
        growingBlocks[best] = entry
        // Un testo che cresce non entra nella cache principale a ogni pezzo (vedi `GrowingInline`).
        if !continues { blocksCache.setObject(Cached(blocks), forKey: key) }
        return blocks
    }

    private static func remember(_ entry: GrowingBlocks) {
        growingBlocks.append(entry)
        if growingBlocks.count > growingBlocksLimit { growingBlocks.removeFirst() }
    }

    /// Legge solo quello che segue la parte stabile di `entry` e sposta la parte stabile fino all'ultima riga vuota completa.
    private static func parseGrowing(_ normalized: String, from entry: GrowingBlocks,
                                     raw: String) -> (GrowingBlocks, [Block]) {
        var entry = entry
        let utf8 = normalized.utf8
        let start = utf8.index(utf8.startIndex, offsetBy: entry.stableText.utf8.count)
        if let boundary = lastStableBoundary(in: normalized, from: start) {
            entry.stableBlocks += parseNormalized(String(normalized[start..<boundary]))
            entry.stableText = String(normalized[..<boundary])
            let blocks = entry.stableBlocks + parseNormalized(String(normalized[boundary...]))
            entry.lastText = raw
            entry.lastBlocks = blocks
            return (entry, blocks)
        }
        let blocks = entry.stableBlocks + parseNormalized(String(normalized[start...]))
        entry.lastText = raw
        entry.lastBlocks = blocks
        return (entry, blocks)
    }

    /// Dopo l'ultima riga vuota completa (terminata da `\n`) che sta fuori da un blocco di codice, a partire da `start`
    /// (che è già fuori da un blocco di codice). nil se non ce n'è. Le righe si riconoscono come nel parsing.
    private static func lastStableBoundary(in text: String, from start: String.Index) -> String.Index? {
        let utf8 = text.utf8
        var inFence = false
        var boundary: String.Index?
        var lineStart = start
        while let newline = utf8[lineStart...].firstIndex(of: UInt8(ascii: "\n")) {
            let trimmed = text[lineStart..<newline].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
            } else if !inFence, trimmed.isEmpty {
                boundary = utf8.index(after: newline)
            }
            lineStart = utf8.index(after: newline)
        }
        return boundary
    }

    /// I fine riga "\r\n" diventano "\n". Il controllo sui byte evita di toccare il testo che non ne ha
    /// (in Swift "\r\n" è un solo Character: `contains("\r")` non lo vedrebbe).
    private static func normalizedNewlines(_ text: String) -> String {
        text.utf8.contains(13) ? text.replacingOccurrences(of: "\r\n", with: "\n") : text
    }

    /// Confronto sui byte: molto più veloce di quello di `String` (che confronta per equivalenza canonica).
    private static func sameBytes(_ a: String, _ b: String) -> Bool {
        a.utf8.count == b.utf8.count && a.utf8.elementsEqual(b.utf8)
    }

    private static func startsWith(_ text: String, _ prefix: String) -> Bool {
        text.utf8.count >= prefix.utf8.count && text.utf8.starts(with: prefix.utf8)
    }

    /// Il parsing di tutto il testo, senza memoria: è quello che i risultati ricordati devono sempre eguagliare (vedi i test).
    static func parse(_ text: String) -> [Block] {
        parseNormalized(normalizedNewlines(text))
    }

    /// Il parsing a righe di un testo che ha già i fine riga normalizzati.
    private static func parseNormalized(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var listItems: [ListItem] = []
        let lines = text.components(separatedBy: "\n")

        func flushParagraph() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            paragraph = []
        }
        func flushList() {
            if !listItems.isEmpty { blocks.append(.list(listItems)) }
            listItems = []
        }
        func flush() { flushParagraph(); flushList() }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Codice
            if trimmed.hasPrefix("```") {
                flush()
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                blocks.append(.code(code.joined(separator: "\n")))
                i += 1
                continue
            }

            if trimmed.isEmpty {
                flush()
                i += 1
                continue
            }

            // Tabella GFM: riga di intestazione + riga di separazione
            if trimmed.hasPrefix("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flush()
                let header = cells(trimmed)
                var rows: [[String]] = []
                i += 2
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    var row = cells(lines[i])
                    row += Array(repeating: "", count: max(0, header.count - row.count))
                    rows.append(Array(row.prefix(header.count)))
                    i += 1
                }
                blocks.append(.table(header, rows))
                continue
            }

            // Prima un controllo sul primo carattere: la gran parte delle righe è testo e non vale una regex.
            let lead = trimmed.first
            if lead == "#", let heading = trimmed.firstMatch(of: /^(#{1,6})\s+(.*)$/) {
                flush()
                blocks.append(.heading(heading.1.count, String(heading.2)))
            } else if lead == "*" || lead == "_", paragraph.isEmpty, listItems.isEmpty || lines[i - 1].trimmingCharacters(in: .whitespaces).isEmpty,
                      let bold = trimmed.firstMatch(of: /^(?:\*\*|__)([^*_]+?)(?:\*\*|__)(:?)$/) {
                // Una riga tutta in grassetto ("**Cause probabili:**") è un titolo di sezione scritto male.
                flush()
                blocks.append(.heading(3, String(bold.1) + String(bold.2)))
            } else if lead == "-" || lead == "*" || lead == "_", trimmed.utf8.count >= 3,
                      trimmed.firstMatch(of: /^(-{3,}|\*{3,}|_{3,})$/) != nil {
                flush()
                blocks.append(.rule)
            } else if trimmed.hasPrefix(">") {
                flush()
                blocks.append(.quote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))
            } else if startsListItem(line), let item = line.firstMatch(of: /^(\s*)([-*+]|\d{1,3}[.)])\s+(.*)$/) {
                flushParagraph()
                let depth = item.1.count / 2
                let marker = item.2.first?.isNumber == true ? String(item.2) : "•"
                listItems.append(ListItem(marker: marker, text: String(item.3), depth: min(depth, 3)))
            } else if !listItems.isEmpty, line.first?.isWhitespace == true {
                // Riga di continuazione dell'ultimo punto
                let last = listItems.removeLast()
                listItems.append(ListItem(marker: last.marker, text: last.text + " " + trimmed, depth: last.depth))
            } else {
                flushList()
                paragraph.append(line)
            }
            i += 1
        }
        flush()
        return blocks
    }

    /// Il primo carattere che non è uno spazio è quello di un punto elenco o una cifra: altrimenti la regex non può combaciare.
    private static func startsListItem(_ line: String) -> Bool {
        guard let first = line.first(where: { !$0.isWhitespace }) else { return false }
        return first == "-" || first == "*" || first == "+" || first.isNumber
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("|") && t.allSatisfy { "|-: ".contains($0) } && t.contains("-")
    }

    private static func cells(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
