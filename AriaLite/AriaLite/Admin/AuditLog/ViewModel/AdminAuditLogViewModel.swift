//
//  AdminAuditLogViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo storico delle modifiche, come la pagina /audit-log della web. Vive in AppViewModel: i dati restano fra un
//  cambio di sezione e l'altro. Tipo di oggetto e azione filtrano sul server (a pagine da 50); la ricerca
//  lavora sulle righe scaricate. Righe e dettaglio in +Rows.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAuditLogViewModel {
    let backend: AriaBackend

    /// Le modifiche scaricate, dalla più recente, come le dà il server.
    private(set) var entries: [AdminAuditLogEntry] = []
    /// Quante modifiche ci sono in tutto con i filtri scelti.
    private(set) var total: Int?
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    /// Tipi di oggetto e azioni visti finora: i menu li mostrano anche con un filtro attivo.
    private(set) var seenEntityTypes: Set<String> = []
    private(set) var seenActions: Set<String> = []

    /// La pila di navigazione: l'id della modifica aperta nel dettaglio.
    var path: [String] = []
    var searchText = ""
    /// `nil`: tutti i tipi (il parametro non si manda).
    var entityTypeFilter: String?
    /// `nil`: tutte le azioni (il parametro non si manda).
    var actionFilter: String?

    @ObservationIgnored private var loadedKey: String?
    @ObservationIgnored private var lastPageWasFull = false
    @ObservationIgnored private var userNames: [String: String] = [:]
    @ObservationIgnored private var usersCompanyId: String?

    static let pageSize = 50
    static let knownEntityTypes = ["work_order", "maintenance_plan", "asset", "vendor", "purchase_order",
                                   "spare_part", "memory_fact", "document", "team"]
    static let knownActions = ["create", "update", "delete", "soft_delete", "restore"]

    init(backend: AriaBackend) {
        self.backend = backend
    }

    private var api: AdminAuditLogAPI { AdminAuditLogAPI(api: backend.api) }

    /// Cambia quando va richiesta la lista: azienda o filtri (la vista ci appende un `.task`).
    var loadKey: String {
        "\(backend.activeCompanyId ?? "-")|\(entityTypeFilter ?? "all")|\(actionFilter ?? "all")"
    }

    var hasFilters: Bool { entityTypeFilter != nil || actionFilter != nil }

    func clearFilters() {
        entityTypeFilter = nil
        actionFilter = nil
    }

    /// All'uscita dall'account: niente storico dell'azienda precedente.
    func reset() {
        entries = []
        total = nil
        hasLoaded = false
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
        seenEntityTypes = []
        seenActions = []
        path = []
        searchText = ""
        entityTypeFilter = nil
        actionFilter = nil
        loadedKey = nil
        lastPageWasFull = false
        userNames = [:]
        usersCompanyId = nil
    }

    // MARK: Caricamento

    /// La prima pagina. Con un'altra azienda o altri filtri la lista vecchia non si mostra più.
    func load() async {
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        let key = loadKey
        if key != loadedKey {
            entries = []
            total = nil
            hasLoaded = false
            errorMessage = nil
            lastPageWasFull = false
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.page(entityType: entityTypeFilter, action: actionFilter,
                                          offset: 0, limit: Self.pageSize)
            // Il filtro è cambiato durante la richiesta: questa risposta non vale più.
            guard key == loadKey, !Task.isCancelled else { return }
            entries = page.items
            total = page.total
            lastPageWasFull = page.items.count >= Self.pageSize
            remember(page.items)
            hasLoaded = true
            errorMessage = nil
        } catch {
            if key == loadKey, let message = AdminAuditLogFailure.message(for: error, backend: backend) {
                errorMessage = message
            }
        }
        await loadUsersIfNeeded(companyId: companyId)
    }

    /// La pagina dopo: in fondo, senza doppioni (una modifica nuova sposta gli offset).
    func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        let key = loadKey
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await api.page(entityType: entityTypeFilter, action: actionFilter,
                                          offset: entries.count, limit: Self.pageSize)
            guard key == loadKey else { return }
            let known = Set(entries.map(\.id))
            let fresh = page.items.filter { !known.contains($0.id) }
            entries += fresh
            remember(fresh)
            lastPageWasFull = page.items.count >= Self.pageSize
            if let pageTotal = page.total { total = pageTotal }
            // Pagina vuota: il totale era vecchio, non si chiede altro.
            if page.items.isEmpty { total = entries.count }
            errorMessage = nil
        } catch {
            if key == loadKey, let message = AdminAuditLogFailure.message(for: error, backend: backend) {
                errorMessage = message
            }
        }
    }

    /// Ci sono altre pagine: il totale dice quante, altrimenti conta se l'ultima era piena.
    var canLoadMore: Bool {
        guard hasLoaded else { return false }
        if let total { return entries.count < total }
        return lastPageWasFull
    }

    private func remember(_ rows: [AdminAuditLogEntry]) {
        for row in rows {
            if let type = row.entityType { seenEntityTypes.insert(type) }
            if let action = row.action { seenActions.insert(action) }
        }
    }

    /// I nomi per lo storico: un di più. Se il ruolo non vede gli utenti restano gli id, senza errori.
    private func loadUsersIfNeeded(companyId: String) async {
        guard usersCompanyId != companyId else { return }
        guard let users = try? await api.users() else { return }
        userNames = Dictionary(users.compactMap { user in
            user.id.map { ($0, Self.name(of: user)) }
        }) { first, _ in first }
        usersCompanyId = companyId
    }

    private static func name(of user: AdminAuditLogUser) -> String {
        if let name = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return user.email ?? user.id ?? ""
    }

    // MARK: Filtri

    /// Le scelte dei menu: quelle note, più quelle viste nelle righe, in ordine alfabetico per nome.
    var entityTypeOptions: [String] {
        sortedByLabel(Set(Self.knownEntityTypes).union(seenEntityTypes).union(entityTypeFilter.map { [$0] } ?? []),
                      AdminAuditLogText.entityTypeLabel)
    }

    var actionOptions: [String] {
        sortedByLabel(Set(Self.knownActions).union(seenActions).union(actionFilter.map { [$0] } ?? []),
                      AdminAuditLogText.actionLabel)
    }

    private func sortedByLabel(_ values: Set<String>, _ label: (String) -> String) -> [String] {
        values.sorted { label($0).localizedStandardCompare(label($1)) == .orderedAscending }
    }

    /// La ricerca cerca in chi, che cosa, il nome, l'azione e i campi: sulle righe già scaricate.
    var visibleEntries: [AdminAuditLogEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            searchFields(of: entry).contains { $0.localizedStandardContains(query) }
        }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func searchFields(of entry: AdminAuditLogEntry) -> [String] {
        [actorName(for: entry), AdminAuditLogText.entityTypeLabel(entry.entityType), entry.displayName,
         entry.entityId, AdminAuditLogText.actionLabel(entry.action)]
            .compactMap { $0 } + entry.changes.map { AdminAuditLogText.humanize($0.field) }
    }

    // MARK: Nomi

    /// Chi ha fatto la modifica: il nome, o l'id se non si conosce; `System` per le azioni automatiche.
    func actorName(for entry: AdminAuditLogEntry) -> String {
        guard let userId = entry.userId else { return String(localized: "System") }
        return userNames[userId] ?? userId
    }

    func entry(id: String) -> AdminAuditLogEntry? { entries.first { $0.id == id } }
}
