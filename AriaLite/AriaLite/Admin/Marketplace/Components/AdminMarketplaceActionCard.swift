//
//  AdminMarketplaceActionCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La scheda sotto l'intestazione: il pulsante Acquista… con il prezzo, lo stato dell'elemento (incluso, acquistato, in arrivo) con la sua nota
//  oppure, per un connettore, il suo passo (abilita, chiave, collega) e il link alla pagina del connettore.
//

import AuthenticationServices
import SwiftUI

struct AdminMarketplaceActionCard: View {
    let viewModel: AdminMarketplaceItemDetailViewModel

    @Environment(\.openURL) private var openURL
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch viewModel.action {
            case .buy(let price):
                Button {
                    viewModel.confirmsPurchase = true
                } label: {
                    HStack(spacing: 8) {
                        Label("Buy…", systemImage: "bag")
                        Text(verbatim: price).fontWeight(.regular).opacity(0.85)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.liteAccent)
                .foregroundStyle(Color.liteOnAccent)
                .controlSize(.large)
            case .status(let status):
                statusView(status)
            case .connector(let panel):
                connectorView(panel)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ariaGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Parti

    @ViewBuilder
    private func statusView(_ status: AdminMarketplaceItemStatus) -> some View {
        if let title = status.title {
            Label {
                Text(verbatim: title)
            } icon: {
                Image(systemName: status.systemImage)
                    .foregroundStyle(status.isOwned ? Color.green : Color.secondary)
            }
            .font(.headline)
        } else {
            Image(systemName: status.systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        if let note = status.note {
            Text(verbatim: note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Il consenso lo esegue il view model; qui solo le azioni dell'ambiente: la sessione web e il browser.
    @ViewBuilder
    private func connectorView(_ panel: AdminMarketplaceConnectorPanel) -> some View {
        if let status = panel.status { statusView(status) }
        if let command = panel.command {
            Button {
                Task {
                    await viewModel.run(command, authenticate: webAuthenticationSession.authenticateConsent,
                                        open: { openURL($0) })
                }
            } label: {
                Label(command.title, systemImage: command.systemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.liteAccent)
            .foregroundStyle(Color.liteOnAccent)
            .controlSize(.large)
            .disabled(viewModel.isWorking || panel.isChecking)
        }
        if viewModel.isWorking || panel.isChecking {
            ProgressView().controlSize(.small)
        }
        if let notice = viewModel.actionNotice {
            AdminSectionNotice(text: notice, systemImage: "info.circle")
        }
        if let provider = panel.openProvider {
            NavigationLink(value: AdminMarketplaceRoute.connector(provider)) {
                Label("Open connector", systemImage: "arrow.right.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Color.liteAccent)
        }
    }
}
