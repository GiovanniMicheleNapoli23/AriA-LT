//
//  AdminConnectorCredentialsFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form della chiave di un connettore: MaintainX (solo la chiave; l'organizzazione si sceglie solo se
//  la chiave ne vede più d'una) o un server MCP con credenziale statica (URL, modo, chiave). Il server
//  verifica prima di salvare: una chiave sbagliata non tocca il connettore che funziona.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminConnectorCredentialsFormViewModel: Identifiable {
    enum Mode { case maintainX, remote }

    let backend: AriaBackend
    let mode: Mode
    let provider: String
    let connectorName: String

    var apiKey = ""
    var serverURL = ""
    var authMode: AdminConnectorAuthMode = .bearer
    var headerName = ""
    var displayName = ""
    /// L'organizzazione scelta quando la chiave ne vede più d'una.
    var organizationId: String?

    /// Le organizzazioni fra cui scegliere (dalla risposta del primo salvataggio).
    private(set) var organizations: [AdminConnectorOrganization] = []
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    /// La chiave c'era già: lasciarla vuota non è permesso dal server, si dice "nuova chiave".
    let hasStoredKey: Bool

    @ObservationIgnored private let onSaved: (AdminConnector) -> Void

    /// MaintainX: `existing` è la riga attuale (o `nil` se il server non la elenca).
    init(backend: AriaBackend, maintainX existing: AdminConnector?, onSaved: @escaping (AdminConnector) -> Void = { _ in }) {
        self.backend = backend
        mode = .maintainX
        provider = AdminConnector.maintainXProvider
        connectorName = existing?.name ?? AdminConnector.prettyName(AdminConnector.maintainXProvider)
        hasStoredKey = existing?.keyHint != nil
        organizationId = existing?.organizationId
        organizations = existing?.organizations ?? []
        self.onSaved = onSaved
    }

    /// Server MCP con credenziale statica: URL, modo e nome partono da quelli salvati.
    init(backend: AriaBackend, remote connector: AdminConnector, onSaved: @escaping (AdminConnector) -> Void = { _ in }) {
        self.backend = backend
        mode = .remote
        provider = connector.provider
        connectorName = connector.name
        hasStoredKey = connector.keyHint != nil
        serverURL = connector.mcpUrl ?? ""
        authMode = AdminConnectorAuthMode(rawValue: connector.authMode.lowercased()) ?? .bearer
        displayName = connector.displayName ?? ""
        organizationId = connector.organizationId
        organizations = connector.organizations
        self.onSaved = onSaved
    }

    // MARK: Validazione

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var needsKey: Bool { mode == .maintainX || authMode != .none }
    var needsHeaderName: Bool { mode == .remote && authMode == .header }
    var choosesOrganization: Bool { organizations.count > 1 }

    var canSave: Bool {
        guard !isSaving else { return false }
        if needsKey && trimmed(apiKey).isEmpty { return false }
        if needsHeaderName && trimmed(headerName).isEmpty { return false }
        if mode == .remote, URL(string: trimmed(serverURL))?.scheme?.hasPrefix("http") != true { return false }
        return true
    }

    var title: String { connectorName }

    var keyFieldTitle: String {
        hasStoredKey ? String(localized: "New API key") : String(localized: "API key")
    }

    // MARK: Salvataggio

    /// `true` quando il form ha finito e si chiude; `false` se c'è un errore o un'organizzazione da scegliere.
    func save() async -> Bool {
        guard canSave, let companyId = backend.activeCompanyId else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let saved = try await backend.api.call(endpoint(companyId))
            onSaved(saved)
            // La chiave vede più organizzazioni e il server non ne ha scelta una: si chiede, senza chiudere.
            if saved.organizationId == nil, saved.organizations.count > 1 {
                organizations = saved.organizations
                errorMessage = String(localized: "This key can act on several organizations. Choose one and save again.")
                return false
            }
            return true
        } catch {
            errorMessage = AdminMarketplaceFailure.message(for: error, backend: backend)
            return false
        }
    }

    private func endpoint(_ companyId: String) -> AriaEndpoint<AdminConnector> {
        let key = trimmed(apiKey)
        switch mode {
        case .maintainX:
            return AdminMarketplaceAPI.connectMaintainX(
                companyId: companyId, AdminConnectorMaintainXConnect(apiKey: key, organizationId: organizationId))
        case .remote:
            let name = trimmed(displayName)
            let body = AdminConnectorRemoteConnect(
                mcpUrl: trimmed(serverURL), authMode: authMode.rawValue,
                apiKey: authMode == .none ? nil : key,
                authHeaderName: needsHeaderName ? trimmed(headerName) : nil,
                organizationId: organizationId, displayName: name.isEmpty ? nil : name)
            return AdminMarketplaceAPI.connectRemote(companyId: companyId, provider: provider, body)
        }
    }
}
