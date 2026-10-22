//
//  AdminLLMUsagePricingSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il listino dei modelli, chiuso di default: prezzo di input e di output per milione di token.
//

import SwiftUI

struct AdminLLMUsagePricingSection: View {
    @Bindable var viewModel: AdminLLMUsageViewModel

    var body: some View {
        DisclosureGroup(isExpanded: $viewModel.showsPricing) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.top, 12)
        } label: {
            Label("Pricing", systemImage: "tag")
                .font(.headline)
                .labelStyle(.titleAndIcon)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var content: some View {
        if let failure = viewModel.pricingFailure {
            AdminLLMUsageNote(message: failure) { Task { await viewModel.loadPricing() } }
        }
        if let pricing = viewModel.pricing {
            VStack(alignment: .leading, spacing: 2) {
                Text("Price list \(pricing.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !pricing.fxSource.isEmpty {
                    Text("Exchange rate: \(pricing.fxSource)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if pricing.rows.isEmpty {
                Text("No prices.").font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(pricing.rows) { row in
                    priceRow(row, currency: pricing.currency)
                }
            }
        } else if viewModel.isLoadingPricing {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func priceRow(_ row: AdminLLMUsagePriceRow, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.model).font(.subheadline.weight(.semibold))
            Text(row.provider).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Text("Input \(AdminLLMUsageFormat.money(row.inputPerMtokEur, currency: currency))")
                Text("Output \(AdminLLMUsageFormat.money(row.outputPerMtokEur, currency: currency))")
            }
            .font(.footnote.monospacedDigit())
            Text("per 1M tokens").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
