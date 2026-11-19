//
//  AdminUsageSpendCapHistorySection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Limit history" (contratto 5.2): la tabella della web come elenco, una riga per modifica con la data UTC e
//  l'anno, chi l'ha fatta (col chip "Owner"), il limite di prima e quello nuovo. Segnaposto finché i nomi non sono letti.
//

import SwiftUI

struct AdminUsageSpendCapHistorySection: View {
    let billing: AdminUsageBillingViewModel

    var body: some View {
        if let card = billing.historyCard {
            AdminUsageCardFrame(title: Text(verbatim: card.title), description: Text(verbatim: card.description)) {
                content(card)
            }
        }
    }

    @ViewBuilder
    private func content(_ card: AdminUsageSpendCapHistoryCard) -> some View {
        switch card.content {
        case .loading:
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    if index > 0 { Divider() }
                    AdminUsageSpendCapHistoryRow(row: Self.placeholder, columns: card.columns).redacted(reason: .placeholder)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading the limit history")
        case .failed(let text):
            VStack(alignment: .leading, spacing: 10) {
                AdminUsageBillingAlertBox(text: text)
                Button("Retry") { Task { await billing.retryHistory() } }
                    .buttonStyle(.bordered)
                    .tint(Color.liteAccent)
            }
        case .empty(let text):
            Text(verbatim: text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        case .rows(let rows):
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    if row.id > 0 { Divider() }
                    AdminUsageSpendCapHistoryRow(row: row, columns: card.columns)
                }
            }
        }
    }

    /// Una riga finta per i segnaposto: ha la forma di una vera.
    private static let placeholder = AdminUsageSpendCapHistoryCard.Row(
        id: 0, date: "Jan 1, 2026", changedBy: "Placeholder name", ownerChip: nil, oldLimit: "€000", newLimit: "€000")
}

/// Una modifica: la data, chi l'ha fatta e i due limiti, letta di seguito da VoiceOver.
struct AdminUsageSpendCapHistoryRow: View {
    let row: AdminUsageSpendCapHistoryCard.Row
    /// Le intestazioni: data, chi, limite di prima, limite nuovo.
    let columns: [String]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: row.date).font(.subheadline.weight(.semibold).monospacedDigit())
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: row.changedBy).font(.footnote).foregroundStyle(.secondary)
                if let chip = row.ownerChip { AdminUsageBillingChip(text: chip) }
            }
            limits
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var limits: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 20))
        return layout {
            limit(title: columns[2], value: row.oldLimit)
            limit(title: columns[3], value: row.newLimit, strong: true)
        }
    }

    private func limit(title: String, value: String, strong: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.footnote.weight(strong ? .semibold : .regular).monospacedDigit())
        }
    }

    private var accessibilityText: String {
        let chip = row.ownerChip.map { ", \($0)" } ?? ""
        return "\(row.date), \(row.changedBy)\(chip), \(columns[2]) \(row.oldLimit), \(columns[3]) \(row.newLimit)"
    }
}
