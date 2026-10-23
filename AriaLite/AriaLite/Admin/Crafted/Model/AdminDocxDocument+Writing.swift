//
//  AdminDocxDocument+Writing.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Scrive le modifiche di un rapporto dentro il .docx (docxWithEdits della web), sui byte di
//  word/document.xml: ogni paragrafo modificato si trova per posizione se il testo combacia, altrimenti
//  per testo se è l'unico; tiene `w:pPr` e il `w:rPr` della prima run e mette una run sola col testo
//  nuovo. Se anche una sola modifica non si può collocare con certezza, torna l'originale con
//  complete = false: un file con una modifica nel paragrafo sbagliato è peggio dell'originale.
//

import Foundation

nonisolated extension AdminDocxDocument {
    /// Il file con le modifiche scritte; `complete` è false se ne è rimasta fuori qualcuna (e `data` è l'originale).
    func writing(_ edits: AdminCraftedReportEdits) -> (data: Data, complete: Bool) {
        if edits.blocks.isEmpty { return (original, true) }
        guard let rewritten = rewrittenXML(edits) else { return (original, false) }
        var copy = archive
        copy.setData(rewritten, for: "word/document.xml")
        guard let zipped = try? copy.zipped() else { return (original, false) }
        return (zipped, true)
    }

    /// Un paragrafo trovato nei byte, nello stesso ordine di apertura dei blocchi.
    private nonisolated struct ParagraphRange {
        var open: AdminDocxXMLScanner.Tag
        var closeStart: Int
        var end: Int
        var hasNested = false
    }

    private static func normalize(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func rewrittenXML(_ edits: AdminCraftedReportEdits) -> Data? {
        let bytes = [UInt8](documentXML)
        let scanner = AdminDocxXMLScanner(bytes: bytes)
        guard let prefix = Self.wordPrefix(scanner), let ranges = Self.paragraphRanges(scanner, prefix: prefix),
              ranges.count == blocks.count else { return nil }

        // Dove va ogni modifica.
        let normalized = blocks.map { Self.normalize($0.text) }
        var targets: [Int: String] = [:]
        for (index, edit) in edits.blocks {
            let before = Self.normalize(edit.before)
            var placed: Int?
            if index >= 0, index < normalized.count, normalized[index] == before {
                placed = index
            } else if !before.isEmpty {
                let matches = normalized.indices.filter { normalized[$0] == before }
                if matches.count == 1 { placed = matches[0] }
            }
            guard let target = placed, targets[target] == nil, !ranges[target].hasNested else { return nil }
            targets[target] = edit.after
        }

        // Dall'ultimo al primo, così le posizioni dei precedenti restano valide.
        var out = bytes
        for index in targets.keys.sorted(by: >) {
            guard let replacement = Self.paragraph(ranges[index], text: targets[index] ?? "", scanner: scanner, prefix: prefix) else { return nil }
            out.replaceSubrange(ranges[index].open.start..<ranges[index].end, with: replacement)
        }
        return Data(out)
    }

    /// Il prefisso del namespace di Word (di solito `w`), letto dal primo elemento. Senza prefisso non si scrive.
    private static func wordPrefix(_ scanner: AdminDocxXMLScanner) -> String? {
        guard let root = scanner.nextTag(from: 0) else { return nil }
        let header = String(decoding: scanner.bytes[root.start..<root.end], as: UTF8.self)
        let marker = "=\"\(AdminDocxBlockParser.wordNamespace)\""
        guard let found = header.range(of: marker) else { return nil }
        let before = header[..<found.lowerBound]
        guard let colon = before.lastIndex(of: ":"), before[..<colon].hasSuffix("xmlns") else { return nil }
        let prefix = String(before[before.index(after: colon)...])
        return prefix.isEmpty ? nil : prefix
    }

    /// Tutti i `w:p` nell'ordine in cui si aprono; `nil` se le chiusure non tornano.
    private static func paragraphRanges(_ scanner: AdminDocxXMLScanner, prefix: String) -> [ParagraphRange]? {
        let name = "\(prefix):p"
        var ranges: [ParagraphRange] = []
        var stack: [Int] = []
        var cursor = 0
        while let tag = scanner.nextTag(from: cursor) {
            cursor = tag.end
            guard tag.name == name else { continue }
            if tag.isClosing {
                guard let index = stack.popLast() else { return nil }
                ranges[index].closeStart = tag.start
                ranges[index].end = tag.end
            } else {
                if let parent = stack.last { ranges[parent].hasNested = true }
                ranges.append(ParagraphRange(open: tag, closeStart: tag.end, end: tag.end))
                if !tag.isSelfClosing { stack.append(ranges.count - 1) }
            }
        }
        return stack.isEmpty ? ranges : nil
    }

    /// Il paragrafo riscritto: stessa apertura e `w:pPr`, una run sola col `w:rPr` della prima.
    private static func paragraph(_ range: ParagraphRange, text: String, scanner: AdminDocxXMLScanner, prefix: String) -> [UInt8]? {
        let bytes = scanner.bytes
        var open = Array(bytes[range.open.start..<range.open.end])
        if range.open.isSelfClosing {
            // `<w:p …/>` → `<w:p …>`
            guard open.count >= 2 else { return nil }
            open.removeLast(2)
            open.append(UInt8(ascii: ">"))
        }
        var properties: [UInt8] = []
        var runProperties: [UInt8] = []
        if !range.open.isSelfClosing {
            let limit = range.closeStart
            var cursor = range.open.end
            // `w:pPr` è il primo figlio, se c'è.
            if let first = scanner.nextTag(from: cursor, limit: limit), !first.isClosing, first.name == "\(prefix):pPr",
               bytes[cursor..<first.start].allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) {
                guard let end = scanner.elementEnd(of: first, limit: limit) else { return nil }
                properties = Array(bytes[first.start..<end])
                cursor = end
            }
            // Il `w:rPr` della prima run.
            while let tag = scanner.nextTag(from: cursor, limit: limit) {
                cursor = tag.end
                guard !tag.isClosing, tag.name == "\(prefix):r" else { continue }
                if !tag.isSelfClosing, let child = scanner.nextTag(from: tag.end, limit: limit), !child.isClosing,
                   child.name == "\(prefix):rPr" {
                    guard let end = scanner.elementEnd(of: child, limit: limit) else { return nil }
                    runProperties = Array(bytes[child.start..<end])
                }
                break
            }
        }
        var out = open + properties
        out += Array("<\(prefix):r>".utf8) + runProperties
        out += Array("<\(prefix):t xml:space=\"preserve\">\(escaped(text))</\(prefix):t></\(prefix):r></\(prefix):p>".utf8)
        return out
    }

    /// Il testo per un elemento XML: `& < >` in entità e fuori i caratteri di controllo che XML 1.0 non ammette.
    private static func escaped(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default:
                let value = scalar.value
                if value < 0x20, value != 0x09, value != 0x0A, value != 0x0D { continue }
                if value == 0xFFFE || value == 0xFFFF { continue }
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
