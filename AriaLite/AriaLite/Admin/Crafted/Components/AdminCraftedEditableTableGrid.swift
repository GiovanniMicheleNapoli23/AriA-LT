//
//  AdminCraftedEditableTableGrid.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una tabella di Aria aperta alla modifica: ogni cella è un campo, ogni riga si toglie, in fondo se ne
//  aggiunge una. Le colonne restano quelle di Aria. La tabella può essere larga: scorre in orizzontale
//  solo lei; "Aggiungi riga" sta fuori, sempre raggiungibile.
//

import SwiftUI

struct AdminCraftedEditableTableGrid: View {
    let viewModel: AdminCraftedArtifactReaderViewModel
    let table: AdminCraftedEditableTable

    @ScaledMetric(relativeTo: .footnote) private var cellWidth: CGFloat = 150

    var body: some View {
        AriaCard {
            if let title = table.title {
                Text(title).font(.subheadline.weight(.semibold))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        ForEach(table.columns) { column in
                            Text(column.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .frame(width: cellWidth, alignment: .leading)
                        }
                        Color.clear.frame(width: 1, height: 1)
                    }
                    ForEach(viewModel.draftRows(table)) { row in
                        GridRow {
                            ForEach(table.columns) { column in
                                TextField(column.label, text: cellBinding(row, column))
                                    .font(.footnote)
                                    .padding(8)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .frame(width: cellWidth)
                            }
                            Button("Remove row", systemImage: "minus.circle.fill", role: .destructive) {
                                viewModel.removeRow(row.id, from: table)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            Button("Add row", systemImage: "plus") { viewModel.addRow(to: table) }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
        }
    }

    private func cellBinding(_ row: AdminCraftedEditedRow, _ column: AdminCraftedColumn) -> Binding<String> {
        Binding(
            get: { viewModel.cellText(table, rowId: row.id, column: column) },
            set: { viewModel.setCell($0, table: table, rowId: row.id, column: column) }
        )
    }
}
