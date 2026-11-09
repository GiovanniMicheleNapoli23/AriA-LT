//
//  AdminConnectorDetailView.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un connettore: intestazione con stato, azioni, scheda, tool esposti e connessioni
//  dei membri. Il consenso OAuth si apre nel browser (Composio nella sessione web dell'app); tornando nell'app lo stato si rilegge da sé.
//

import AuthenticationServices
import SwiftUI

struct AdminConnectorDetailView: View {
    @State private var viewModel: AdminConnectorDetailViewModel

    @Environment(\.openURL) private var openURL
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AdminConnectorDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let message = viewModel.connectorError {
                    AdminSectionNotice(text: message, isError: true)
                }
                AdminConnectorActionsCard(viewModel: viewModel, onConsent: consent)
                detailsCard
                if !viewModel.connector.allowedInstances.isEmpty { instancesCard }
                AdminConnectorToolsCard(viewModel: viewModel)
                if viewModel.showsGrants { AdminConnectorGrantsCard(viewModel: viewModel) }
            }
            .padding(20)
            .ariaReadableWidth()
        }
        .liteBackground()
        .navigationTitle(viewModel.connector.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.returnedFromConsent() } }
        }
        .onChange(of: viewModel.didRemove) { _, removed in
            if removed { dismiss() }
        }
        .sheet(item: $viewModel.credentialsForm) { form in
            AdminConnectorCredentialsFormView(viewModel: form) {
                Task { await viewModel.credentialsSaved() }
            }
        }
        .alert("Couldn't complete the action", isPresented: $viewModel.showsActionError) {
            Button("OK") {}
        } message: {
            Text(viewModel.actionError ?? "")
        }
        .alert(viewModel.disconnectTitle, isPresented: $viewModel.confirmsDisconnect) {
            Button(viewModel.disconnectTitle, role: .destructive) { Task { await viewModel.disconnect() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.disconnectWarning)
        }
        .alert("Disconnect your account?", isPresented: $viewModel.confirmsDisconnectMine) {
            Button("Disconnect", role: .destructive) { Task { await viewModel.disconnectMine() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Aria will no longer act on this system on your behalf.")
        }
        .alert("Access for Aria", isPresented: $viewModel.confirmsConsent) {
            Button("Read only") { consent(personal: false, write: false) }
            Button("Read and write") { consent(personal: false, write: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose what Aria may do in this system. You approve it in the browser.")
        }
        .alert("Revoke this connection?", isPresented: $viewModel.showsRevokeConfirmation,
               presenting: viewModel.grantToRevoke) { grant in
            Button("Revoke", role: .destructive) { Task { await viewModel.revoke(grant) } }
            Button("Cancel", role: .cancel) {}
        } message: { grant in
            Text("\(grant.title) will have to connect their account again.")
        }
    }

    /// Il consenso lo esegue il view model; qui solo le azioni dell'ambiente: la sessione web e il browser.
    private func consent(personal: Bool, write: Bool) {
        Task {
            await viewModel.consent(personal: personal, requestWrite: write,
                                    authenticate: webAuthenticationSession.authenticateConsent,
                                    open: { openURL($0) })
        }
    }

    // MARK: Sezioni

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            AdminConnectorIcon(provider: viewModel.connector.provider, name: viewModel.connector.name)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.connector.name)
                    .font(.title3.weight(.bold))
                Text(viewModel.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                AdminConnectorStatusBadge(status: viewModel.connector.status)
            }
            Spacer(minLength: 0)
        }
    }

    private var detailsCard: some View {
        AdminCard(title: "Details", systemImage: "info.circle") {
            let fields = viewModel.fields
            VStack(spacing: 0) {
                ForEach(fields) { field in
                    AdminFieldRow(field: field, showsDivider: field != fields.last)
                }
            }
        }
    }

    private var instancesCard: some View {
        AdminCard(title: "Approved databases", systemImage: "cylinder.split.1x2") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.connector.allowedInstances) { instance in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instance.title).font(.subheadline.weight(.semibold))
                        if let description = instance.description, !description.isEmpty {
                            Text(description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
