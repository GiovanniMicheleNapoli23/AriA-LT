//
//  AdminMarketplaceViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Marketplace, come la pagina /marketplace della web: i connettori dell'azienda in griglia,
//  divisi per stato, con ricerca. Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  Non c'è una rotta di catalogo: la griglia è quello che risponde GET /connectors.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMarketplaceViewModel {
    let backend: AriaBackend

    private(set) var connectors: [AdminConnector] = []
    private(set) var isLoading = false
    /// La lista è arrivata almeno una volta per l'azienda attiva.
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?

    var searchText = ""
    /// Il form della chiave MaintainX aperto dalla barra (quando MaintainX non è nella lista).
    var maintainXForm: AdminConnectorCredentialsFormViewModel?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesta la lista: l'azienda attiva.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    // MARK: Ruolo

    /// Owner e admin gestiscono i connettori; senza ruolo noto si lascia decidere al server (403).
    var canManage: Bool { AdminMarketplaceViewModel.canManage(backend) }

    static func canManage(_ backend: AriaBackend) -> Bool {
        let role = backend.companies.first { $0.id == backend.activeCompanyId }?.myRole?.lowercased()
        guard let role else { return true }
        return role == "owner" || role == "admin"
    }

    // MARK: Gruppi

    /// I connettori filtrati dalla ricerca, divisi per stato (solo i gruppi non vuoti).
    var sections: [AdminMarketplaceSection] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = connectors
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) || $0.provider.localizedStandardContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return AdminMarketplaceSection.Kind.allCases.compactMap { kind in
            let items = visible.filter { kind.contains($0.knownStatus) }
            return items.isEmpty ? nil : AdminMarketplaceSection(kind: kind, connectors: items)
        }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var connectedCount: Int { connectors.filter { $0.knownStatus == .connected }.count }
    var attentionCount: Int { connectors.filter { $0.knownStatus == .attention }.count }
    var toolCount: Int { connectors.filter { $0.knownStatus == .connected }.reduce(0) { $0 + $1.toolCount } }

    /// MaintainX si collega con una chiave anche quando il server non lo elenca.
    var canAddMaintainX: Bool { canManage && !connectors.contains(where: \.isMaintainX) }

    func connector(for provider: String) -> AdminConnector? {
        connectors.first { $0.provider == provider }
    }

    // MARK: Caricamento

    func load() async {
        // Altra azienda: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        let key = loadKey
        if key != loadedKey {
            connectors = []
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminMarketplaceAPI.connectors(companyId: companyId))
            guard key == loadKey, !Task.isCancelled else { return }
            connectors = response.connectors
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
        } catch {
            guard key == loadKey, let message = AdminMarketplaceFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    // MARK: Dopo una modifica

    /// Un connettore cambiato nel dettaglio o nel form: si aggiorna la riga senza ricaricare.
    func apply(_ connector: AdminConnector) {
        if let index = connectors.firstIndex(where: { $0.provider == connector.provider }) {
            connectors[index] = connector
        } else {
            connectors.append(connector)
        }
    }

    func makeDetailViewModel(for provider: String) -> AdminConnectorDetailViewModel? {
        guard let connector = connector(for: provider) else { return nil }
        return AdminConnectorDetailViewModel(
            backend: backend, connector: connector,
            onChanged: { [weak self] in self?.apply($0) },
            onRemoved: { [weak self] in Task { await self?.load() } })
    }

    func openMaintainXForm() {
        maintainXForm = AdminConnectorCredentialsFormViewModel(backend: backend, maintainX: nil) { [weak self] in self?.apply($0) }
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        connectors = []
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        searchText = ""
        maintainXForm = nil
    }
}

/// Un gruppo della griglia: da sistemare, collegati, non collegati.
nonisolated struct AdminMarketplaceSection: Identifiable, Sendable {
    enum Kind: CaseIterable, Sendable {
        case attention, connected, available

        func contains(_ status: AdminConnectorStatus) -> Bool {
            switch self {
            case .attention: status == .attention
            case .connected: status == .connected
            case .available: status == .pending || status == .disconnected
            }
        }

        var title: String {
            switch self {
            case .attention: String(localized: "Needs attention")
            case .connected: String(localized: "Connected")
            case .available: String(localized: "Not connected")
            }
        }
    }

    let kind: Kind
    let connectors: [AdminConnector]

    var id: Kind { kind }
}
