//
//  AdminConnectorActionsCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le azioni di un connettore: connetti (OAuth o chiave), la mia connessione, verifica e scollega.
//  Compaiono solo quelle che il tipo di connettore e il ruolo permettono (lo decide il view model).
//

import SwiftUI

struct AdminConnectorActionsCard: View {
    @Bindable var viewModel: AdminConnectorDetailViewModel
    /// Apre il consenso nel browser (`personal`: la mia connessione).
    let onConsent: (_ personal: Bool, _ write: Bool) -> Void

    @ScaledMetric(relativeTo: .body) private var buttonWidth: CGFloat = 200

    var body: some View {
        AdminCard(title: "Connection", systemImage: "link") {
            if viewModel.isWorking { ProgressView().controlSize(.small) }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                if let error = viewModel.connector.lastError {
                    AdminSectionNotice(text: error, isError: true)
                }
                if let line = viewModel.myGrantLine {
                    AdminSectionNotice(text: line, systemImage: "person.crop.circle")
                }
                if let notice = viewModel.actionNotice {
                    AdminSectionNotice(text: notice, systemImage: "info.circle")
                }
                if viewModel.awaitingConsent {
                    Button("Refresh status", systemImage: "arrow.clockwise") {
                        Task { await viewModel.returnedFromConsent() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Color.liteAccent)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: buttonWidth), spacing: 10)], alignment: .leading, spacing: 10) {
                    buttons
                }
                .disabled(viewModel.isWorking)
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if viewModel.showsCompanyConsent {
            action(viewModel.companyConsentTitle, "arrow.up.forward.app", prominent: !viewModel.isConnected) {
                viewModel.confirmsConsent = true
            }
        }
        if viewModel.showsMyConsent {
            action(viewModel.myConsentTitle, "person.badge.key", prominent: viewModel.connector.myGrant == nil) {
                onConsent(true, false)
            }
        }
        if viewModel.showsCredentials {
            action(viewModel.credentialsTitle, "key", prominent: !viewModel.isConnected) {
                viewModel.openCredentialsForm()
            }
        }
        if viewModel.showsVerify {
            action(viewModel.verifyTitle, "checkmark.arrow.trianglehead.counterclockwise") {
                Task { await viewModel.verify() }
            }
        }
        if viewModel.showsDisconnectMine {
            action(String(localized: "Disconnect my account"), "person.crop.circle.badge.xmark", role: .destructive) {
                viewModel.confirmsDisconnectMine = true
            }
        }
        if viewModel.showsDisconnect {
            action(viewModel.disconnectTitle, "trash", role: .destructive) {
                viewModel.confirmsDisconnect = true
            }
        }
    }

    @ViewBuilder
    private func action(_ title: String, _ systemImage: String, role: ButtonRole? = nil, prominent: Bool = false,
                        perform: @escaping () -> Void) -> some View {
        let button = Button(role: role, action: perform) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        if prominent {
            button.buttonStyle(.borderedProminent).tint(Color.liteAccent).foregroundStyle(Color.liteOnAccent)
        } else {
            button.buttonStyle(.bordered).tint(role == .destructive ? .red : Color.liteAccent)
        }
    }
}
