//
//  AdminLLMUsageSessionRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sessione di chat nell'elenco: titolo, stato, modello, durata, costo e Stop per quelle attive.
//

import SwiftUI

struct AdminLLMUsageSessionRow: View {
    let session: AdminLLMUsageSession
    let canStop: Bool
    let isStopping: Bool
    let onStop: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    statusLabel
                    Text(AdminLLMUsageFormat.money(session.totals.costEur))
                        .font(.caption.monospacedDigit())
                    if let seconds = session.durationS {
                        Text(AdminLLMUsageFormat.duration(seconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 8)
            if session.isActive {
                Button(role: .destructive, action: onStop) {
                    if isStopping {
                        ProgressView()
                    } else {
                        Text("Stop")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!canStop)
            }
        }
        .padding(.vertical, 6)
    }

    /// Il titolo lo scrive l'utente: si mostra così com'è.
    private var titleText: String {
        guard let title = session.title, !title.isEmpty else { return String(localized: "Untitled session") }
        return title
    }

    /// Modello e provider, poi la data d'inizio.
    private var detailText: String {
        var parts: [String] = []
        if let model = session.model, !model.isEmpty { parts.append(model) }
        if let provider = session.provider, !provider.isEmpty { parts.append(provider) }
        if let started = session.startedAt {
            parts.append(started.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch session.status.lowercased() {
        case "active": Text("Active").foregroundStyle(.green)
        case "ended", "completed": Text("Ended").foregroundStyle(.secondary)
        case "stopped": Text("Stopped").foregroundStyle(.orange)
        default: Text(session.status.replacingOccurrences(of: "_", with: " ").capitalized).foregroundStyle(.secondary)
        }
    }
}
