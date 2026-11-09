//
//  AdminLLMUsageModelRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un modello nel riepilogo: nome, costo e token, con una barra proporzionale al modello più costoso.
//

import SwiftUI

struct AdminLLMUsageModelRow: View {
    let model: AdminLLMUsageModel
    /// Quota della barra, da 0 a 1.
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.model)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    if let cost = model.costEur {
                        Text(AdminLLMUsageFormat.money(cost))
                            .font(.subheadline.monospacedDigit())
                    } else {
                        Text("No price")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(AdminLLMUsageFormat.tokens(model.totalTokens)) tokens")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(Color.liteAccent)
                        .frame(width: proxy.size.width * max(0, min(1, share)))
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
    }

    /// Provider e fase (agente, altro) con le chiamate.
    private var detail: String {
        let calls = model.nCalls == 1 ? String(localized: "1 call") : String(localized: "\(model.nCalls) calls")
        return [model.provider, model.stage, calls].joined(separator: " · ")
    }
}
