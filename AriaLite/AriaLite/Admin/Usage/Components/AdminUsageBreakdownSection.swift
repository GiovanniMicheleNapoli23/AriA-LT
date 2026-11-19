//
//  AdminUsageBreakdownSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Where credits went" (contratto 3.7): colonne per azione, utente, agente (o "Your usage" per un membro).
//  Su iPhone le colonne stanno una sotto l'altra, su iPad una accanto all'altra (griglia adattiva).
//

import SwiftUI

struct AdminUsageBreakdownSection: View {
    let breakdown: AdminUsageBreakdown

    var body: some View {
        AdminUsageCardFrame(title: Text(verbatim: breakdown.title), description: Text(verbatim: breakdown.description)) {
            VStack(alignment: .leading, spacing: 16) {
                if let note = breakdown.note {
                    Text(verbatim: note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 20, alignment: .top)], alignment: .leading, spacing: 20) {
                    ForEach(breakdown.columns) { column in
                        AdminUsageBreakdownColumnView(column: column, emptyText: breakdown.emptyText)
                    }
                }
            }
        }
    }
}

struct AdminUsageBreakdownColumnView: View {
    let column: AdminUsageBreakdownColumn
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: column.title)
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if column.rows.isEmpty {
                Text(verbatim: emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(column.rows) { AdminUsageBreakdownRowView(row: $0) }
            }
            if let foot = column.foot {
                Text(verbatim: foot)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Una riga: nome (sfocato finché il nome si legge), crediti e la barra della sua quota.
struct AdminUsageBreakdownRowView: View {
    let row: AdminUsageBreakdownRow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            AriaCreditsMeter(fill: row.fraction, tick: nil, tint: Color.liteAccent)
            if let note = row.note {
                Text(verbatim: note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            name
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(verbatim: row.credits)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var name: some View {
        if row.isPending {
            Text(verbatim: "Member name")
                .font(.subheadline)
                .redacted(reason: .placeholder)
                .accessibilityLabel("Loading")
        } else {
            Text(verbatim: row.name)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
