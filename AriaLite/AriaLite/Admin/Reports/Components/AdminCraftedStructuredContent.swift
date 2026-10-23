//
//  AdminCraftedStructuredContent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I dati di un widget che non è una card conosciuta: valori "chiave: valore", liste di oggetti come
//  tabelle (Grid, con scorrimento orizzontale solo dentro la tabella) e oggetti annidati in JSON compatto.
//

import SwiftUI

struct AdminCraftedStructuredContent: View {
    let fields: [AdminAssetField]
    let tables: [AdminCraftedTable]
    let nested: [AdminAssetField]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !fields.isEmpty {
                AdminCard(title: "Values", systemImage: "list.bullet.rectangle") {
                    rows(fields)
                }
            }
            ForEach(tables) { table in
                AdminCard(title: LocalizedStringKey(table.title ?? String(localized: "Rows")), systemImage: "tablecells") {
                    tableView(table)
                }
            }
            if !nested.isEmpty {
                AdminCard(title: "Details", systemImage: "curlybraces") {
                    rows(nested)
                }
            }
            if fields.isEmpty, tables.isEmpty, nested.isEmpty {
                AdminSectionNotice(text: String(localized: "This widget's data has a shape the app can't show yet. Open it on the web."),
                                   systemImage: "questionmark.square.dashed")
            }
        }
    }

    private func rows(_ items: [AdminAssetField]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { field in
                AdminFieldRow(field: field, showsDivider: field != items.last)
            }
        }
    }

    private func tableView(_ table: AdminCraftedTable) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    ForEach(table.columns, id: \.self) { column in
                        Text(column.replacingOccurrences(of: "_", with: " "))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                            Text(value)
                                .font(.footnote)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }
}
