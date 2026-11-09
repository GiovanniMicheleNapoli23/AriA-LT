//
//  AdminDocxXMLScanner.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Scorre i tag di un XML già in byte, senza costruirne l'albero: dà dove inizia e finisce ogni tag
//  e il suo nome. Serve a riscrivere word/document.xml toccando solo i byte dei paragrafi modificati.
//  Salta commenti, istruzioni di elaborazione e CDATA; le virgolette negli attributi non chiudono il tag.
//

import Foundation

nonisolated struct AdminDocxXMLScanner {
    nonisolated struct Tag: Sendable {
        /// Posizione del `<`.
        var start: Int
        /// Posizione subito dopo il `>`.
        var end: Int
        /// Il nome com'è scritto, col prefisso (`w:p`), senza `/`.
        var name: String
        var isClosing: Bool
        var isSelfClosing: Bool
    }

    let bytes: [UInt8]

    init(bytes: [UInt8]) { self.bytes = bytes }

    /// Il primo tag di elemento (non commento, né `<?…?>`, né CDATA) da `from` fino a `limit`.
    func nextTag(from: Int, limit: Int? = nil) -> Tag? {
        let stop = min(limit ?? bytes.count, bytes.count)
        var i = from
        while i < stop {
            guard bytes[i] == UInt8(ascii: "<") else { i += 1; continue }
            if let skipped = skipSpecial(at: i) { i = skipped; continue }
            // Il nome: fino a spazio, `>` o `/`.
            var j = i + 1
            let closing = j < stop && bytes[j] == UInt8(ascii: "/")
            if closing { j += 1 }
            let nameStart = j
            while j < stop, !Self.isNameEnd(bytes[j]) { j += 1 }
            let name = String(decoding: bytes[nameStart..<j], as: UTF8.self)
            // La fine del tag, fuori dalle virgolette.
            var quote: UInt8?
            while j < stop {
                let byte = bytes[j]
                if let open = quote {
                    if byte == open { quote = nil }
                } else if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") {
                    quote = byte
                } else if byte == UInt8(ascii: ">") {
                    let selfClosing = bytes[j - 1] == UInt8(ascii: "/") && !closing
                    return Tag(start: i, end: j + 1, name: name, isClosing: closing, isSelfClosing: selfClosing)
                }
                j += 1
            }
            return nil
        }
        return nil
    }

    /// Dove finisce l'elemento aperto da `open`, contando gli elementi con lo stesso nome annidati.
    func elementEnd(of open: Tag, limit: Int? = nil) -> Int? {
        if open.isSelfClosing { return open.end }
        var depth = 1
        var cursor = open.end
        while let tag = nextTag(from: cursor, limit: limit) {
            cursor = tag.end
            guard tag.name == open.name else { continue }
            if tag.isClosing {
                depth -= 1
                if depth == 0 { return tag.end }
            } else if !tag.isSelfClosing {
                depth += 1
            }
        }
        return nil
    }

    private static func isNameEnd(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: ">") || byte == UInt8(ascii: "/") || byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }

    /// Se in `at` c'è un commento, un `<?…?>`, un CDATA o un `<!…>`, dove finisce; altrimenti `nil`.
    private func skipSpecial(at: Int) -> Int? {
        guard at + 1 < bytes.count else { return nil }
        let next = bytes[at + 1]
        if next == UInt8(ascii: "?") { return find("?>", from: at + 2) }
        guard next == UInt8(ascii: "!") else { return nil }
        if hasPrefix("<!--", at: at) { return find("-->", from: at + 4) }
        if hasPrefix("<![CDATA[", at: at) { return find("]]>", from: at + 9) }
        return find(">", from: at + 2)
    }

    private func hasPrefix(_ text: String, at: Int) -> Bool {
        let needle = Array(text.utf8)
        return at + needle.count <= bytes.count && bytes[at..<(at + needle.count)].elementsEqual(needle)
    }

    /// La posizione subito dopo la prima occorrenza di `text` da `from`; se non c'è, la fine (XML malformato).
    private func find(_ text: String, from: Int) -> Int {
        let needle = Array(text.utf8)
        var i = from
        while i + needle.count <= bytes.count {
            if bytes[i] == needle[0], bytes[i..<(i + needle.count)].elementsEqual(needle) { return i + needle.count }
            i += 1
        }
        return bytes.count
    }
}
