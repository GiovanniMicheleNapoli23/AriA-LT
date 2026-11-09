//
//  AdminCraftedTableDiffGrid.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Una tabella letta contro un'altra versione: la cella cambiata mostra prima il vecchio valore barrato
//  e poi il nuovo, una riga aggiunta è su verde, una tolta su rosso e barrata. La tabella può essere
//  larga: solo lei scorre in orizzontale, la pagina no.
//

import SwiftUI

struct AdminCraftedTableDiffGrid: View {
    let table: AdminCraftedCompareTable

    /// Le celle si allargano con il testo, così a testo grande le righe restano leggibili.
    @ScaledMetric(relativeTo: .footnote) private var cellWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .footnote) private var markerWidth: CGFloat = 14

    var body: some View {
        AriaCard {
            if let title = table.title {
                Text(title).font(.subheadline.weight(.semibold))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 9) {
                    GridRow {
                        Color.clear.frame(width: markerWidth, height: 1)
                        ForEach(table.columns) { column in
                            Text(column.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .frame(width: cellWidth, alignment: .leading)
                        }
                    }
                    Divider()
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            marker(row)
                            ForEach(table.columns) { column in
                                cell(row, column: column).frame(width: cellWidth, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    private func marker(_ row: AdminCraftedRowDiff) -> some View {
        Text(markerText(row))
            .font(.footnote.monospaced())
            .foregroundStyle(markerColor(row))
            .frame(width: markerWidth)
            .accessibilityHidden(true)
    }

    private func markerText(_ row: AdminCraftedRowDiff) -> String {
        switch row {
        case .added: "+"
        case .removed: "−"
        case .row: ""
        }
    }

    private func markerColor(_ row: AdminCraftedRowDiff) -> Color {
        switch row {
        case .added: .green
        case .removed: .red
        case .row: .secondary
        }
    }

    @ViewBuilder
    private func cell(_ row: AdminCraftedRowDiff, column: AdminCraftedColumn) -> some View {
        switch row {
        case .removed(let before):
            Text(AdminCraftedRowDiff.text(before[column.key])).font(.footnote).strikethrough().foregroundStyle(.red)
        case .added(let cells):
            Text(AdminCraftedRowDiff.text(cells[column.key])).font(.footnote)
                .padding(.horizontal, 4).background(Color.green.opacity(0.28), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .row(let cells, let before, let changed):
            let now = AdminCraftedRowDiff.text(cells[column.key])
            if changed.contains(column.key) {
                changedCell(before: AdminCraftedRowDiff.text(before[column.key]), now: now)
            } else {
                Text(now.isEmpty ? "—" : now).font(.footnote).foregroundStyle(now.isEmpty ? .secondary : .primary)
            }
        }
    }

    private func changedCell(before: String, now: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !before.isEmpty {
                Text(before).font(.footnote).strikethrough()
                    .padding(.horizontal, 4).background(Color.red.opacity(0.24), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            if !now.isEmpty {
                Text(now).font(.footnote)
                    .padding(.horizontal, 4).background(Color.green.opacity(0.28), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }
}
