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

    static func inline(_ text: String) -> AttributedString {
        let key = text as NSString
        if let hit = inlineCache.object(forKey: key) { return hit.value }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let parsed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        inlineCache.setObject(Cached(parsed), forKey: key)
        return parsed
    }

    static func blocks(_ text: String) -> [Block] {
        let key = text as NSString
        if let hit = blocksCache.object(forKey: key) { return hit.value }
        let parsed = parseBlocks(text)
        blocksCache.setObject(Cached(parsed), forKey: key)
        return parsed
    }

    private static func parseBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var listItems: [ListItem] = []
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")

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

            if let heading = trimmed.firstMatch(of: /^(#{1,6})\s+(.*)$/) {
                flush()
                blocks.append(.heading(heading.1.count, String(heading.2)))
            } else if paragraph.isEmpty, listItems.isEmpty || lines[i - 1].trimmingCharacters(in: .whitespaces).isEmpty,
                      let bold = trimmed.firstMatch(of: /^(?:\*\*|__)([^*_]+?)(?:\*\*|__)(:?)$/) {
                // Una riga tutta in grassetto ("**Cause probabili:**") è un titolo di sezione scritto male.
                flush()
                blocks.append(.heading(3, String(bold.1) + String(bold.2)))
            } else if trimmed.firstMatch(of: /^(-{3,}|\*{3,}|_{3,})$/) != nil {
                flush()
                blocks.append(.rule)
            } else if trimmed.hasPrefix(">") {
                flush()
                blocks.append(.quote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))
            } else if let item = line.firstMatch(of: /^(\s*)([-*+]|\d{1,3}[.)])\s+(.*)$/) {
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
