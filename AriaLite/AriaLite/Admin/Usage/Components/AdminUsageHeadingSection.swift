//
//  AdminUsageHeadingSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'intestazione della pagina Usage (contratto 3.2): "{plan} · {month} cycle", la riga dei fatti e il selettore
//  "Billing cycle". Il selettore resta anche mentre il cruscotto si legge o dopo un errore.
//

import SwiftUI

struct AdminUsageHeadingSection: View {
    let title: String?
    let facts: String?
    /// Il cruscotto si sta leggendo: il titolo è un segnaposto.
    let isLoading: Bool
    let options: [AdminUsageCycleOption]
    let selectedStart: String?
    let select: (AdminUsageCycleOption) -> Void

    var body: some View {
        // Senza titolo, segnaposto né selettore non c'è niente da mostrare: nessuna scheda vuota.
        if title != nil || isLoading || !options.isEmpty { card }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: title)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let facts {
                        Text(verbatim: facts)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            } else if isLoading {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "Professional · November 2026 cycle").font(.title3.weight(.semibold))
                    Text(verbatim: "Nov 1 – Nov 30 · Resets Dec 1, 00:00 UTC").font(.footnote)
                }
                .redacted(reason: .placeholder)
                .accessibilityHidden(true)
            }
            if !options.isEmpty { picker }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.liteSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var picker: some View {
        let current = options.first { $0.id == selectedStart }
        return Menu {
            ForEach(options) { option in
                Button { select(option) } label: {
                    if option.id == selectedStart {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(verbatim: option.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Billing cycle").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: current?.title ?? options.first?.title ?? "").font(.subheadline.weight(.medium))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(.primary)
        .accessibilityLabel("Billing cycle")
        .accessibilityValue(current?.title ?? "")
    }
}
