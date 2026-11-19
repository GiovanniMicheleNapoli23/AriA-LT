//
//  AdminUsageMetersSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Included credits" (contratto 3.5): Today e This week. Nascosta, in attesa con un segnaposto, fallita con
//  "Retry" o pronta con i due contatori.
//

import SwiftUI

struct AdminUsageMetersSection: View {
    let state: AdminUsageMetersState
    let title: String
    let description: String
    let retry: () -> Void

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .loading:
            AdminUsageCardFrame(title: Text(verbatim: title), description: Text(verbatim: description)) {
                AdminUsagePlaceholderLines(lines: 4)
            }
        case .failed(let message):
            AdminUsageCardFrame(title: Text(verbatim: title), description: Text(verbatim: description)) {
                AdminUsageRetryNote(message: message, retry: retry)
            }
        case .ready(let card):
            AdminUsageCardFrame(title: Text(verbatim: card.title), description: Text(verbatim: card.description)) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(card.meters) { AdminUsageMeterRow(meter: $0) }
                }
            }
        }
    }
}

/// Un contatore: nome, crediti usati, barra (con la tacca dell'avviso per Today) e le righe sotto.
struct AdminUsageMeterRow: View {
    let meter: AdminUsageMeter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            AriaCreditsMeter(fill: meter.fraction, tick: meter.tick, tint: meter.tone.tint)
            figures
            if let tickLabel = meter.tickLabel { footnote(tickLabel) }
            if let overText = meter.overText { footnote(overText) }
            if let reset = meter.resetText { footnote(reset) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(verbatim: meter.label).font(.subheadline.weight(.semibold))
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(verbatim: meter.used)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }

    private var figures: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(verbatim: meter.ofIncluded)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(verbatim: meter.percentText).monospacedDigit()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func footnote(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Righe finte per una scheda in attesa.
struct AdminUsagePlaceholderLines: View {
    var lines = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<lines, id: \.self) { _ in
                Text(verbatim: "Placeholder text for a line of the card").font(.subheadline)
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

/// Il messaggio di una scheda che non si è potuta leggere, con "Retry".
struct AdminUsageRetryNote: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}
