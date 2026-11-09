//
//  AdminLLMUsageSummarySection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il riepilogo del periodo: quattro cifre, il costo per giorno e la ripartizione per modello.
//

import SwiftUI

struct AdminLLMUsageSummarySection: View {
    let viewModel: AdminLLMUsageViewModel

    var body: some View {
        AdminCard(title: "Usage", systemImage: "chart.bar.xaxis", accessory: {
            if viewModel.isLoadingSummary, viewModel.summary != nil { ProgressView() }
        }, content: {
            if let failure = viewModel.summaryFailure {
                AdminLLMUsageNote(message: failure) { Task { await viewModel.loadSummary() } }
            }
            if viewModel.summary != nil {
                loaded
            } else if viewModel.isLoadingSummary {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.summaryFailure == nil {
                Text("No usage data yet.").font(.footnote).foregroundStyle(.secondary)
            }
        })
    }

    @ViewBuilder
    private var loaded: some View {
        let totals = viewModel.totals
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            AdminLLMUsageKPITile(title: "Cost", value: AdminLLMUsageFormat.money(totals.costEur))
            AdminLLMUsageKPITile(title: "Tokens in", value: AdminLLMUsageFormat.tokens(totals.promptTokens))
            AdminLLMUsageKPITile(title: "Tokens out", value: AdminLLMUsageFormat.tokens(totals.completionTokens))
            AdminLLMUsageKPITile(
                title: "Requests",
                value: totals.nCalls.formatted(.number),
                caption: totals.unpricedCalls > 0 ? "\(totals.unpricedCalls) without price" : nil
            )
        }
        if totals.unpricedCalls > 0 {
            Text("\(totals.unpricedCalls) calls have no price and are not included in the cost.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if viewModel.chartDays.isEmpty {
            Text("No usage in this period.").font(.footnote).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cost per day").font(.subheadline.weight(.semibold))
                AdminLLMUsageDailyChart(days: viewModel.chartDays)
            }
        }

        let models = viewModel.summary?.byModel ?? []
        if !models.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("By model").font(.subheadline.weight(.semibold))
                ForEach(models) { model in
                    AdminLLMUsageModelRow(model: model, share: viewModel.share(of: model))
                    if model.id != models.last?.id { Divider() }
                }
            }
        }
    }
}
