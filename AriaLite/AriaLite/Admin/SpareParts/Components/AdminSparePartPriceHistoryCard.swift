//
//  AdminSparePartPriceHistoryCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo storico dei costi unitari (dai ricambi usati negli ordini di lavoro): ultimo, minimo, massimo e
//  media in alto, poi le righe più recenti; le altre si aprono con "Show all".
//

import SwiftUI

struct AdminSparePartPriceHistoryCard: View {
    let viewModel: AdminSparePartDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Price history", systemImage: "chart.line.uptrend.xyaxis").font(.headline)
            switch viewModel.historyState {
            case .loading:
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: message).font(.subheadline).foregroundStyle(.secondary)
                    Button("Retry") { Task { await viewModel.retryHistory() } }
                        .font(.subheadline.weight(.semibold))
                }
            case .loaded:
                if viewModel.priceHistory.isEmpty {
                    Text("No price history yet. It fills in as work orders use this part.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if let summary = viewModel.priceSummary { summaryGrid(summary) }
                    entries
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryGrid(_ summary: AdminSparePartDetailViewModel.PriceSummary) -> some View {
        // Due colonne sempre: su iPhone stretto quattro valori in fila non ci stanno.
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                stat("Latest", summary.latest)
                stat("Average", summary.average)
            }
            GridRow {
                stat("Lowest", summary.lowest)
                stat("Highest", summary.highest)
            }
        }
    }

    private func stat(_ title: LocalizedStringKey, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: AdminSparePartDetailViewModel.formatPrice(value))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entries: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.visibleHistory) { entry in
                Divider()
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: entry.date.map(AdminSparePartDetailViewModel.formatDate) ?? "—")
                            .font(.subheadline)
                        if let workOrder = entry.workOrder {
                            Text("Work order \(workOrder)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: entry.unitCost.map(AdminSparePartDetailViewModel.formatPrice) ?? "—")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        if let quantity = entry.quantity {
                            Text("Qty \(AdminSparePartDetailViewModel.formatQuantity(quantity))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 10)
            }
            if viewModel.hiddenHistoryCount > 0 {
                Divider()
                Button {
                    withAnimation(.snappy) { viewModel.toggleHistory() }
                } label: {
                    Group {
                        if viewModel.showsAllHistory { Text("Show less") }
                        else { Text("Show all (\(viewModel.priceHistory.count))") }
                    }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liteAccent)
            }
        }
    }
}
