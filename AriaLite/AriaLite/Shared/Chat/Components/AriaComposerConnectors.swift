//
//  AriaComposerConnectors.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il pulsante dei connettori nella barra della chat e il suo popover, come quello della memoria: i connettori
//  collegati e "Manage connectors", che porta al Marketplace già filtrato sui connettori.
//  La logica sta in AriaComposerConnectorsViewModel.
//

import SwiftUI

struct AriaComposerConnectorsButton: View {
    @Bindable var model: AriaChatComposerViewModel
    let access: AriaChatConnectorsAccess
    /// Prima di passare al Marketplace (la tastiera si chiude).
    var onManage: () -> Void

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 38

    var body: some View {
        Button { model.showConnectors = true } label: {
            // Come il "+": una spina in un cerchio pieno e tenue di 38, che smette di crescere ad AX1.
            Image(systemName: "powerplug")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: side, height: side)
                .background(Color.primary.opacity(0.08), in: Circle())
                .contentShape(Circle())
                .dynamicTypeSize(...AriaChatComposer.maxButtonTypeSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Connectors")
        .accessibilityIdentifier("chat.connectors")
        .popover(isPresented: $model.showConnectors, arrowEdge: .bottom) {
            AriaComposerConnectorsPopover(marketplace: access.marketplace) {
                model.showConnectors = false
                onManage()
                access.open()
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// I connettori collegati e "Manage connectors".
private struct AriaComposerConnectorsPopover: View {
    @State private var model: AriaComposerConnectorsViewModel
    let manage: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 24

    init(marketplace: AdminMarketplaceViewModel, manage: @escaping () -> Void) {
        _model = State(initialValue: AriaComposerConnectorsViewModel(marketplace: marketplace))
        self.manage = manage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connectors")
                .font(.subheadline.weight(.semibold))
            content
            Button(action: manage) {
                Text("Manage connectors")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Color.liteOnAccent)
            .controlSize(.small)
            .accessibilityIdentifier("chat.manageConnectors")
        }
        .padding(16)
        .frame(width: 280)
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.content {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .restricted:
            note("Owners and admins connect your company’s tools.")
        case .failed(let message):
            Text(verbatim: message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .empty:
            note("No connectors connected yet.")
        case .list(let rows):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        AdminConnectorIcon(provider: row.provider, name: row.name, side: iconSide)
                        Text(verbatim: row.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.liteAccent)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(Text("Connected"))
                }
            }
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
