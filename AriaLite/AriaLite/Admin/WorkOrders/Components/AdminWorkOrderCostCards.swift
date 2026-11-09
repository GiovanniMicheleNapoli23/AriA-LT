//
//  AdminWorkOrderCostCards.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I pezzi della scheda costi: la striscia dei totali, la scheda di una sezione (titolo, subtotale, "+")
//  e la riga di un costo con importo a destra.
//

import SwiftUI

/// Manodopera, ricambi ed extra in piccolo, il totale in grande.
struct AdminWorkOrderCostTotalsStrip: View {
    let totals: AdminWorkOrderCostTotals

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                tile("Labor", totals.labor)
                tile("Parts", totals.parts)
                tile("Extra", totals.extra)
            }
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text("Total").font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(totals.total)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
            }
        }
        .padding(16)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func tile(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Una sezione dei costi: intestazione con subtotale e "+", poi le righe (o una riga vuota).
struct AdminWorkOrderCostSectionCard<Rows: View>: View {
    let kind: AdminWorkOrderCostKind
    let subtotal: String
    let isEmpty: Bool
    let error: String?
    let canAdd: Bool
    let onAdd: () -> Void
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                AdminWorkOrderCardTitle(title: kind.title, icon: kind.icon)
                Spacer(minLength: 8)
                Text(subtotal).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
                if canAdd {
                    Button("Add", systemImage: "plus.circle.fill", action: onAdd)
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(Color.liteAccent)
                        .accessibilityLabel(Text("Add \(kind.title)"))
                }
            }
            .padding(.bottom, 6)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.vertical, 6)
            } else if isEmpty {
                Text(kind.emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
            rows()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Una riga di costo: titolo e dettagli a sinistra, importo a destra.
struct AdminWorkOrderCostRowView: View {
    let item: AdminWorkOrderCostRowItem
    let isDeleting: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if isDeleting {
                ProgressView().controlSize(.small)
            } else {
                Text(item.amount).font(.subheadline.monospacedDigit())
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(isDeleting ? 0.5 : 1)
    }
}
