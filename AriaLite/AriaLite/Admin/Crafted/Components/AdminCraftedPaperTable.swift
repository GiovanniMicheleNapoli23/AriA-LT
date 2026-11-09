//
//  AdminCraftedPaperTable.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una tabella del rapporto come griglia con i bordi. Le colonne dividono la larghezza della pagina;
//  se non ci stanno (ognuna ha una larghezza minima) è la tabella, e solo lei, a scorrere di lato.
//

import SwiftUI

struct AdminCraftedPaperTable: View {
    let viewModel: AdminCraftedReportReaderViewModel
    /// Riga per riga, i blocchi di ogni cella.
    let rows: [[[Int]]]

    @State private var available: CGFloat = 0
    @ScaledMetric private var minColumn = 120.0
    @ScaledMetric private var padding = 6.0

    private var columns: Int { max(rows.map(\.count).max() ?? 1, 1) }

    var body: some View {
        let width = max(minColumn, available / CGFloat(columns))
        ScrollView(.horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { column in
                            cell(rows[row].indices.contains(column) ? rows[row][column] : [], width: width)
                        }
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { available = $0 }
    }

    private func cell(_ blocks: [Int], width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(blocks, id: \.self) { index in
                AdminCraftedPaperBlock(viewModel: viewModel, index: index, isInTable: true)
            }
        }
        .padding(padding)
        .frame(width: width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .border(AdminCraftedPaperStyle.line, width: 0.5)
    }
}
