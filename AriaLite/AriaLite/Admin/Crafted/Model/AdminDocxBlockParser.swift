//
//  AdminDocxBlockParser.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Legge word/document.xml con XMLParser e ne ricava i blocchi in ordine di lettura: ogni `w:p`, anche
//  dentro le celle di una tabella, con il suo testo (`w:t`; un `w:tab` in una run vale uno spazio), se è
//  un titolo e in quale riga e colonna di quale tabella sta. L'indice è l'ordine di apertura dei `w:p`:
//  lo stesso con cui AdminDocxDocument.writing li ritrova nei byte.
//

import Foundation

nonisolated final class AdminDocxBlockParser: NSObject, XMLParserDelegate {
    static let wordNamespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

    private struct TableState {
        let index: Int
        var row = -1
        var column = -1
    }

    private(set) var blocks: [AdminDocxDocument.Block] = []
    private var open: [Int] = []
    private var names: [String] = []
    private var tables: [TableState] = []
    private var tableCount = 0
    private var inText = false

    static func parse(_ data: Data) throws -> [AdminDocxDocument.Block] {
        let delegate = AdminDocxBlockParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw AdminDocxDocument.Failure.invalidXML }
        return delegate.blocks
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let word = namespaceURI == Self.wordNamespace
        let parent = names.last
        names.append(word ? elementName : "")
        guard word else { return }
        switch elementName {
        case "p":
            var block = AdminDocxDocument.Block(index: blocks.count, text: "", isHeading: false, headingLevel: nil, table: nil)
            if let table = tables.last, table.row >= 0, table.column >= 0 {
                block.table = .init(table: table.index, row: table.row, column: table.column)
            }
            open.append(blocks.count)
            blocks.append(block)
        case "tbl":
            tables.append(TableState(index: tableCount))
            tableCount += 1
        case "tr":
            if !tables.isEmpty { tables[tables.count - 1].row += 1; tables[tables.count - 1].column = -1 }
        case "tc":
            if !tables.isEmpty { tables[tables.count - 1].column += 1 }
        case "t":
            inText = !open.isEmpty
        case "tab":
            // Solo il tab dentro una run: quelli di `w:tabs` sono tabulazioni dello stile, non testo.
            if parent == "r", let current = open.last { blocks[current].text += " " }
        case "pStyle":
            // Lo stile del paragrafo, non quello di una sua modifica tracciata (`w:pPrChange`).
            if parent == "pPr", names.count >= 3, names[names.count - 3] == "p", let current = open.last,
               let style = attributeDict["w:val"] ?? attributeDict["val"] {
                Self.apply(style: style, to: &blocks[current])
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText, let current = open.last { blocks[current].text += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // Gli elementi di altri namespace hanno nome vuoto nella pila: non toccano i contatori.
        guard let popped = names.popLast(), !popped.isEmpty else { return }
        switch elementName {
        case "p": _ = open.popLast()
        case "tbl": _ = tables.popLast()
        case "t": inText = false
        default: break
        }
    }

    /// `Heading1`, `Heading 2`, `Title`: titolo (livello 0 per `Title`).
    private static func apply(style: String, to block: inout AdminDocxDocument.Block) {
        let lowered = style.lowercased().replacingOccurrences(of: " ", with: "")
        if lowered == "title" {
            block.isHeading = true
            block.headingLevel = 0
        } else if lowered.hasPrefix("heading") {
            block.isHeading = true
            block.headingLevel = Int(lowered.dropFirst("heading".count)) ?? 1
        }
    }
}
