//
//  AriaComposerUsageRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Nella riga in basso della barra della chat, quando la tastiera è aperta: il menu dei livelli di effort
//  ("Effort 1×"; si sceglie senza chiudere la tastiera, in fondo "Effort details" apre il foglio con i costi) e
//  alla sua destra il pulsante dei connettori (una spina; popover con i collegati e "Manage connectors"). La logica sta in
//  AriaChatComposerViewModel+Effort e AriaComposerConnectorsViewModel.
//

import SwiftUI

struct AriaComposerUsageRow: View {
    @Bindable var model: AriaChatComposerViewModel
    /// `nil` se la shell non offre il Marketplace: il pulsante dei connettori non c'è.
    var connectors: AriaChatConnectorsAccess?
    /// Prima di passare al Marketplace la tastiera si chiude.
    var onManageConnectors: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            AriaComposerEffortControl(model: model)
                .padding(.leading, 4)
            if let connectors {
                AriaComposerConnectorsButton(model: model, access: connectors, onManage: onManageConnectors)
            }
        }
    }
}

/// Il comando dell'effort: un menu coi livelli, spento mentre si leggono, un pulsante verso l'errore se non si leggono.
struct AriaComposerEffortControl: View {
    @Bindable var model: AriaChatComposerViewModel

    var body: some View {
        switch model.effortEntry {
        case .hidden:
            EmptyView()
        case .loading:
            AriaComposerChip(title: String(localized: "Effort"), icon: AriaChatComposerViewModel.effortIcon,
                             showsChevron: false)
                .opacity(0.5)
                .accessibilityLabel("Loading effort levels")
        case .failed(let title):
            Button { model.showEffort = true } label: {
                AriaComposerChip(title: title, icon: AriaChatComposerViewModel.effortIcon, showsChevron: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityIdentifier("chat.effort")
        case .ready(let title):
            Menu {
                levels
                Section {
                    Button("Effort details", systemImage: "info.circle") { model.showEffort = true }
                }
            } label: {
                AriaComposerChip(title: title, icon: AriaChatComposerViewModel.effortIcon, showsChevron: true)
            }
            .disabled(model.isEffortDisabled)
            .accessibilityLabel(model.effortAccessibilityLabel ?? title)
            .accessibilityIdentifier("chat.effort")
            .sensoryFeedback(.selection, trigger: model.chat.effortLevel)
        }
    }

    private var levels: some View {
        Section("Effort") {
            ForEach(model.effortRows) { row in
                Toggle(isOn: Binding(get: { row.isCurrent }, set: { _ in model.selectEffort(row) })) {
                    Text(verbatim: model.effortTitle(row))
                    if let subtitle = model.effortSubtitle(row) {
                        Text(verbatim: subtitle)
                    }
                }
                // Nel menu la spunta di sistema, non l'interruttore verde dell'app.
                .toggleStyle(.automatic)
                .disabled(row.isLocked)
            }
        }
    }
}

/// La pillola del comando: icona, nome e, sul menu, la freccetta.
private struct AriaComposerChip: View {
    let title: String
    let icon: String
    let showsChevron: Bool

    /// Come le pillole del contesto sopra il campo.
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 32

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption.weight(.semibold))
            Text(verbatim: title).font(.footnote.weight(.medium))
            if showsChevron {
                Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(minHeight: height)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .contentShape(Capsule())
    }
}
