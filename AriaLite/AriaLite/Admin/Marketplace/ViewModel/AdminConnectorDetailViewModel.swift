//
//  AdminConnectorDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un connettore: stato, tool esposti, connessioni dei membri (owner e admin) e azioni
//  (verifica, consenso OAuth, chiave, scollega). Ogni blocco si carica per conto suo: se uno fallisce
//  (o il ruolo non lo vede) gli altri restano. Il consenso OAuth si apre nel browser: al ritorno si ricarica.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminConnectorDetailViewModel {
    let backend: AriaBackend
    let provider: String

    private(set) var connector: AdminConnector
    private(set) var connectorError: String?
    private(set) var tools: AdminConnectorTools?
    private(set) var toolsError: String?
    private(set) var grants: [AdminConnectorGrant] = []
    private(set) var grantsError: String?
    private(set) var isLoading = false
    private(set) var hasLoadedTools = false
    private(set) var hasLoadedGrants = false

    /// Un'azione in corso (verifica, consenso, scollega…): i pulsanti si spengono.
    private(set) var isWorking = false
    private(set) var revokingIds: Set<String> = []
    /// Esito positivo di un'azione, in una riga sotto lo stato.
    private(set) var actionNotice: String?
    /// Il consenso è stato aperto nel browser: al ritorno nell'app si ricarica lo stato.
    private(set) var awaitingConsent = false
    /// Il connettore è stato rimosso: la vista torna alla griglia.
    private(set) var didRemove = false

    var actionError: String?
    var confirmsDisconnect = false
    var confirmsDisconnectMine = false
    var confirmsConsent = false
    var grantToRevoke: AdminConnectorGrant?
    var credentialsForm: AdminConnectorCredentialsFormViewModel?

    /// Per `.alert` e `.confirmationDialog`: chiuderli azzera lo stato.
    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    var showsRevokeConfirmation: Bool {
        get { grantToRevoke != nil }
        set { if !newValue { grantToRevoke = nil } }
    }

    @ObservationIgnored private let onChanged: (AdminConnector) -> Void
    @ObservationIgnored private let onRemoved: () -> Void

    init(backend: AriaBackend, connector: AdminConnector,
         onChanged: @escaping (AdminConnector) -> Void = { _ in }, onRemoved: @escaping () -> Void = {}) {
        self.backend = backend
        self.provider = connector.provider
        self.connector = connector
        self.onChanged = onChanged
        self.onRemoved = onRemoved
    }

    // MARK: Cosa si può fare

    var canManage: Bool { AdminMarketplaceViewModel.canManage(backend) }
    var status: AdminConnectorStatus { connector.knownStatus }
    var isConnected: Bool { status == .connected || status == .attention }

    /// Consenso aziendale (OAuth, una connessione per tutti): solo owner e admin.
    var showsCompanyConsent: Bool { connector.usesOAuth && !connector.isPerMember && canManage }
    var companyConsentTitle: String {
        isConnected ? String(localized: "Reconnect") : String(localized: "Connect")
    }

    /// Connessione personale: ogni membro collega il suo account.
    var showsMyConsent: Bool { connector.isPerMember }
    var myConsentTitle: String {
        connector.myGrant == nil ? String(localized: "Connect my account") : String(localized: "Reconnect my account")
    }
    var showsDisconnectMine: Bool { connector.isPerMember && connector.myGrant != nil }

    /// Chiave da incollare: MaintainX o un server con credenziale statica.
    var showsCredentials: Bool { canManage && (connector.isMaintainX || connector.usesStaticCredential) }
    var credentialsTitle: String {
        if connector.isMaintainX && !isConnected { return String(localized: "Connect with API key") }
        return connector.isMaintainX ? String(localized: "Replace API key") : String(localized: "Update credential")
    }

    /// Verifica: per MaintainX riprova la chiave, per gli altri rilegge i tool del server.
    var showsVerify: Bool {
        guard isConnected else { return false }
        return !connector.isPerMember || connector.myGrant != nil
    }
    var verifyTitle: String {
        connector.isMaintainX ? String(localized: "Test connection") : String(localized: "Refresh tools")
    }

    var showsDisconnect: Bool { canManage && (!connector.isMaintainX || isConnected) }
    var disconnectTitle: String {
        connector.isMaintainX ? String(localized: "Disconnect") : String(localized: "Remove connector")
    }
    var disconnectWarning: String {
        if connector.isPerMember {
            return String(localized: "Every member's connection and the company's OAuth client are deleted. This can't be undone.")
        }
        return String(localized: "The stored credential is deleted. Aria stops using this connector until someone connects it again.")
    }

    var showsGrants: Bool { canManage && connector.isPerMember }

    // MARK: Scheda

    var subtitle: String {
        [connector.isMaintainX ? String(localized: "Built-in") : String(localized: "MCP server"),
         connector.isPerMember ? String(localized: "Each member connects") : String(localized: "Shared by the company")]
            .joined(separator: " · ")
    }

    /// Le righe "Details": solo i campi con un valore.
    var fields: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        func date(_ value: Date?) -> String? { value?.formatted(date: .abbreviated, time: .shortened) }
        add(String(localized: "Status"), AdminConnectorStatus.label(for: connector.status))
        add(String(localized: "Authentication"), AdminConnectorAuthMode.label(for: connector.authMode))
        add(String(localized: "Server"), connector.mcpUrl)
        add(String(localized: "Key"), connector.keyHint.map { "••••\($0)" })
        add(String(localized: "Organization"), connector.organizationName)
        add(String(localized: "Permissions"), connector.grantedScopes.isEmpty ? nil : connector.grantedScopes.joined(separator: ", "))
        add(String(localized: "Exposed tools"), connector.toolCount > 0 ? "\(connector.toolCount)" : nil)
        add(String(localized: "Members connected"), connector.memberCount.map { "\($0)" })
        add(String(localized: "Last verified"), date(connector.lastVerifiedAt))
        add(String(localized: "Tools discovered"), date(connector.lastDiscoveredAt))
        add(String(localized: "Updated"), date(connector.updatedAt))
        add(String(localized: "Updated by"), connector.updatedBy)
        return rows
    }

    /// La riga "la mia connessione" di un connettore personale.
    var myGrantLine: String? {
        guard connector.isPerMember else { return nil }
        guard let grant = connector.myGrant else { return String(localized: "You haven't connected your account yet.") }
        let account = grant.accountEmail ?? AdminConnectorStatus.label(for: grant.status)
        if let date = grant.connectedAt {
            return String(localized: "Connected as \(account) on \(date.formatted(date: .abbreviated, time: .omitted))")
        }
        return String(localized: "Connected as \(account)")
    }

    func tools(in group: AdminConnectorToolGroup) -> [AdminConnectorTool] {
        guard let tools else { return [] }
        return switch group {
        case .runs: tools.runs
        case .asks: tools.asks
        case .unavailable: tools.unavailable
        }
    }

    var toolsSourceNote: String? {
        switch tools?.source {
        case "reviewed"?: String(localized: "Reviewed list: nobody has connected this server yet.")
        case "unreviewed"?: String(localized: "No reviewed list covers this server.")
        default: nil
        }
    }

    // MARK: Caricamento

    func load() async {
        guard let companyId = backend.activeCompanyId else {
            connectorError = AriaError.missingCompany.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        async let row: Void = loadConnector(companyId)
        async let list: Void = loadTools(companyId)
        async let members: Void = loadGrants(companyId)
        _ = await (row, list, members)
    }

    /// Non c'è una GET del singolo connettore: si rilegge l'elenco e si prende la riga.
    private func loadConnector(_ companyId: String) async {
        do {
            let response = try await backend.api.call(AdminMarketplaceAPI.connectors(companyId: companyId))
            if let fresh = response.connectors.first(where: { $0.provider == provider }) {
                update(fresh)
            }
            connectorError = nil
        } catch {
            connectorError = AdminMarketplaceFailure.message(for: error, backend: backend)
        }
    }

    private func loadTools(_ companyId: String) async {
        do {
            tools = try await backend.api.call(AdminMarketplaceAPI.tools(companyId: companyId, provider: provider))
            toolsError = nil
        } catch {
            toolsError = AdminMarketplaceFailure.message(for: error, backend: backend)
        }
        hasLoadedTools = true
    }

    private func loadGrants(_ companyId: String) async {
        guard showsGrants else { return }
        do {
            grants = try await backend.api.call(AdminMarketplaceAPI.grants(companyId: companyId, provider: provider)).grants
            grantsError = nil
        } catch {
            grantsError = AdminMarketplaceFailure.message(for: error, backend: backend)
        }
        hasLoadedGrants = true
    }

    private func update(_ fresh: AdminConnector) {
        connector = fresh
        onChanged(fresh)
    }

    // MARK: Azioni

    /// Test della chiave (MaintainX) o nuova lettura dei tool (server MCP).
    func verify() async {
        await perform { companyId in
            let endpoint = connector.isMaintainX
                ? AdminMarketplaceAPI.verifyMaintainX(companyId: companyId)
                : AdminMarketplaceAPI.refresh(companyId: companyId, provider: provider)
            let fresh = try await backend.api.call(endpoint)
            update(fresh)
            actionNotice = fresh.knownStatus == .connected
                ? String(localized: "Connection verified.")
                : (fresh.lastError ?? String(localized: "The connection didn't pass the check."))
            await loadTools(companyId)
        }
    }

    /// Chiede l'URL del consenso; la vista lo apre nel browser. `nil` se il server ha rifiutato.
    func startConsent(personal: Bool, requestWrite: Bool = false) async -> URL? {
        var target: URL?
        await perform { companyId in
            let endpoint = personal
                ? AdminMarketplaceAPI.startMyOAuth(companyId: companyId, provider: provider)
                : AdminMarketplaceAPI.startOAuth(companyId: companyId, provider: provider, requestWrite: requestWrite)
            let start = try await backend.api.call(endpoint)
            guard let url = URL(string: start.authorizeUrl), url.scheme?.hasPrefix("http") == true else {
                throw AriaError.decoding("authorize_url")
            }
            target = url
            awaitingConsent = true
            actionNotice = String(localized: "Finish signing in in the browser, then come back here.")
        }
        return target
    }

    /// L'app torna in primo piano dopo il consenso: si rilegge lo stato una volta.
    func returnedFromConsent() async {
        guard awaitingConsent else { return }
        awaitingConsent = false
        actionNotice = nil
        await load()
    }

    func disconnect() async {
        await perform { companyId in
            _ = try await backend.api.call(AdminMarketplaceAPI.disconnect(companyId: companyId, provider: provider))
            didRemove = true
            onRemoved()
        }
    }

    func disconnectMine() async {
        await perform { companyId in
            _ = try await backend.api.call(AdminMarketplaceAPI.disconnectMine(companyId: companyId, provider: provider))
            actionNotice = String(localized: "Your account was disconnected.")
            await loadConnector(companyId)
        }
    }

    func revoke(_ grant: AdminConnectorGrant) async {
        guard let companyId = backend.activeCompanyId else { return }
        revokingIds.insert(grant.id)
        defer { revokingIds.remove(grant.id) }
        do {
            _ = try await backend.api.call(AdminMarketplaceAPI.revokeGrant(companyId: companyId, provider: provider,
                                                                          userId: grant.userId))
            grants.removeAll { $0.id == grant.id }
            await loadConnector(companyId)
        } catch {
            actionError = AdminMarketplaceFailure.message(for: error, backend: backend)
        }
    }

    func openCredentialsForm() {
        credentialsForm = connector.isMaintainX
            ? AdminConnectorCredentialsFormViewModel(backend: backend, maintainX: connector, onSaved: { [weak self] in self?.update($0) })
            : AdminConnectorCredentialsFormViewModel(backend: backend, remote: connector, onSaved: { [weak self] in self?.update($0) })
    }

    /// Dopo il form: tool e stato nuovi.
    func credentialsSaved() async {
        guard let companyId = backend.activeCompanyId else { return }
        actionNotice = String(localized: "Credential saved and verified.")
        await loadTools(companyId)
    }

    /// Un'azione alla volta, con l'errore in un avviso.
    private func perform(_ action: (String) async throws -> Void) async {
        guard let companyId = backend.activeCompanyId else {
            actionError = AriaError.missingCompany.localizedDescription
            return
        }
        isWorking = true
        actionNotice = nil
        defer { isWorking = false }
        do {
            try await action(companyId)
        } catch {
            actionError = AdminMarketplaceFailure.message(for: error, backend: backend)
        }
    }
}
