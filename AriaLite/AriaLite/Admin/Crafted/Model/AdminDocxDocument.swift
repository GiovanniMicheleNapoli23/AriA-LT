//
//  AdminDocxDocument.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Un rapporto .docx come lo legge il lettore: i blocchi di word/document.xml in ordine di lettura
//  (paragrafi, titoli, celle di tabella) e la scrittura delle modifiche dentro il file, così scaricare
//  è scaricare il documento che si sta leggendo (docxWithEdits della web).
//

import Foundation

nonisolated struct AdminDocxDocument: Sendable {
    nonisolated enum Failure: Error, Sendable {
        case missingDocument
        case invalidXML
    }

    /// Dove sta un paragrafo di tabella: quale tabella (in ordine di apertura), riga e colonna (da 0).
    nonisolated struct TablePosition: Hashable, Sendable {
        var table: Int
        var row: Int
        var column: Int
    }

    /// Un paragrafo (`w:p`). `index` è l'ordine di lettura, lo stesso della web.
    nonisolated struct Block: Identifiable, Hashable, Sendable {
        var index: Int
        var text: String
        var isHeading: Bool
        /// 0 per `Title`, N per `HeadingN`; `nil` se non è un titolo.
        var headingLevel: Int?
        /// `nil` se il paragrafo non è in una tabella.
        var table: TablePosition?

        var id: Int { index }
    }

    let blocks: [Block]
    /// Il testo di ogni blocco, per indice.
    var texts: [String] { blocks.map(\.text) }

    let original: Data
    let archive: AdminDocxArchive
    let documentXML: Data

    init(data: Data) throws {
        original = data
        archive = try AdminDocxArchive(data: data)
        guard let xml = archive.data(of: "word/document.xml") else { throw Failure.missingDocument }
        documentXML = xml
        blocks = try AdminDocxBlockParser.parse(xml)
    }

    /// Le righe di una tabella come griglia di blocchi: `grid[riga][colonna]` = i paragrafi di quella cella.
    func tableGrid(_ table: Int) -> [[[Block]]] {
        var grid: [[[Block]]] = []
        for block in blocks {
            guard let position = block.table, position.table == table else { continue }
            while grid.count <= position.row { grid.append([]) }
            while grid[position.row].count <= position.column { grid[position.row].append([]) }
            grid[position.row][position.column].append(block)
        }
        return grid
    }
}
