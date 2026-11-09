//
//  AdminCraftedPaperItem.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Come la pagina del rapporto mette in fila i blocchi: un paragrafo alla volta, e una tabella intera
//  al suo primo paragrafo (le sue celle sono altri blocchi, indicati per indice).
//

import Foundation

nonisolated enum AdminCraftedPaperItem: Identifiable, Hashable, Sendable {
    case block(Int)
    /// Numero della tabella e, riga per riga, i blocchi di ogni cella.
    case table(Int, rows: [[[Int]]])

    var id: String {
        switch self {
        case .block(let index): "b\(index)"
        case .table(let table, _): "t\(table)"
        }
    }

    static func layout(of document: AdminDocxDocument) -> [AdminCraftedPaperItem] {
        var items: [AdminCraftedPaperItem] = []
        var seen = Set<Int>()
        for block in document.blocks {
            guard let position = block.table else {
                items.append(.block(block.index))
                continue
            }
            guard seen.insert(position.table).inserted else { continue }
            let rows = document.tableGrid(position.table).map { $0.map { $0.map(\.index) } }
            items.append(.table(position.table, rows: rows))
        }
        return items
    }
}
