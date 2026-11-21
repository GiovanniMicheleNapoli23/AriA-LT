//
//  AriaComposerConnectors.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il popover dei connettori della barra della chat, aperto dalla voce "Connectors" del "+" e ancorato al "+",
//  come quello della memoria: i connettori collegati e "Manage connectors", che porta al Marketplace già
//  filtrato sui connettori.
//  La logica sta in AriaComposerConnectorsViewModel.
//

import SwiftUI

extension View {
    /// Il popover dei connettori ancorato a questa vista; senza Marketplace (`access` nil) non c'è.
    func ariaConnectorsPopover(model: AriaChatComposerViewModel, access: AriaChatConnectorsAccess?,
                               onManage: @escaping () -> Void) -> some View {
        modifier(AriaComposerConnectorsAnchor(model: model, access: access, onManage: onManage))
    }
}

private struct AriaComposerConnectorsAnchor: ViewModifier {
    @Bindable var model: AriaChatComposerViewModel
    let access: AriaChatConnectorsAccess?
    /// Prima di passare al Marketplace (la tastiera si chiude).
    let onManage: () -> Void

    func body(content: Content) -> some View {
        if let access {
            content
                .popover(isPresented: $model.showConnectors, arrowEdge: .bottom) {
                    AriaComposerConnectorsPopover(marketplace: access.marketplace) {
                        model.showConnectors = false
                        onManage()
                        access.open()
                    }
                    .presentationCompactAdaptation(.popover)
                }
        } else {
            content
        }
    }
}

/// I connettori collegati e "Manage connectors".
private struct AriaComposerConnectorsPopover: View {
    @State private var model: AriaComposerConnectorsViewModel
    let manage: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 28

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
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        AdminConnectorIcon(provider: row.provider, name: row.name, side: iconSide)
                        Text(verbatim: row.name)
                            .font(.body)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        // Grande quanto il nome: una spunta da didascalia accanto a un'icona di 28 non si vede.
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.liteOnAccent, Color.liteAccent)
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
