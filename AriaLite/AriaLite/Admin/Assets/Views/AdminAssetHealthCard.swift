//
//  AdminAssetHealthCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  La salute dell'asset nel dettaglio: punteggio e voto, fattori di rischio, raccomandazioni e segnali.
//  Senza punteggio ("No health score yet") o con un errore lo dice in una riga. L'icona di ricalcolo
//  compare solo se il ruolo ha `refresh_health`.
//

import SwiftUI

struct AdminAssetHealthCard: View {
    let viewModel: AdminAssetHealthViewModel

    var body: some View {
        AdminCard(title: "Health score", systemImage: "heart.text.square") {
            if viewModel.canRefresh { refreshButton }
        } content: {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let health = viewModel.health {
            VStack(alignment: .leading, spacing: 16) {
                AdminAssetHealthScore(health: health)
                caption(for: health)
                if !health.riskFactors.isEmpty {
                    AdminAssetHealthList(title: "Risk factors", items: health.riskFactors,
                                         systemImage: "exclamationmark.triangle", tint: .orange)
                }
                if !health.recommendations.isEmpty {
                    AdminAssetHealthList(title: "Recommendations", items: health.recommendations,
                                         systemImage: "lightbulb", tint: Color.liteAccent)
                }
                if !health.signals.isEmpty { signals(health.signals) }
                if let message = viewModel.refreshError {
                    AdminSectionNotice(text: message, isError: true)
                }
            }
        } else if let message = viewModel.loadError {
            AdminSectionNotice(text: message, isError: true)
        } else if viewModel.isNotComputed {
            VStack(alignment: .leading, spacing: 10) {
                AdminSectionNotice(text: String(localized: "No health score yet"), systemImage: "heart.text.square")
                if let message = viewModel.refreshError {
                    AdminSectionNotice(text: message, isError: true)
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            if viewModel.isRefreshing {
                ProgressView()
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .buttonStyle(.borderless)
        .tint(Color.liteAccent)
        .disabled(viewModel.isRefreshing)
        .accessibilityLabel(Text("Refresh health score"))
    }

    private func caption(for health: AdminAssetHealth) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let computed = health.computedAt {
                Text("Computed \(computed.formatted(date: .abbreviated, time: .shortened))")
            }
            Text("Based on the last \(health.windowDays) days")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func signals(_ signals: [AdminAssetHealthSignal]) -> some View {
        DisclosureGroup("Signals") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(signals) { AdminAssetHealthSignalRow(signal: $0) }
            }
            .padding(.top, 8)
        }
        .font(.subheadline.weight(.semibold))
        .tint(.secondary)
    }
}
