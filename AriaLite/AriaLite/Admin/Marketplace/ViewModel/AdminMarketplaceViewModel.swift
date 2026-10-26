//
//  AdminMarketplaceViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Marketplace, come la pagina /marketplace della web: il catalogo (7 tipi, in locale) a scaffali
//  con ricerca e filtri, e i connettori veri dell'azienda (GET /connectors) che ne accendono lo stato.
//  Solo i connettori sono collegabili; gli acquisti restano su questo telefono (AdminMarketplacePurchases).
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMarketplaceViewModel {
    let backend: AriaBackend
    /// Il catalogo e i suoi indici: si costruiscono alla prima apertura della sezione (`ensureCatalog`),
    /// non all'avvio. Con un catalogo passato all'init (i test) sono pronti subito.
    private var index: AdminMarketplaceIndex
    /// Il catalogo è pronto: prima del primo `load()` la lista è vuota perché non è ancora stato letto.
    private(set) var isCatalogReady: Bool
    /// Il catalogo intero, nella lingua dell'app.
    var catalog: [AdminMarketplaceItem] { index.catalog }

    private(set) var connectors: [AdminConnector] = []
    private(set) var isLoading = false
    /// La lista è arrivata almeno una volta per l'azienda attiva.
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?

    /// Gli id globali comprati dall'azienda attiva.
    private(set) var purchases: Set<String> = []
    @ObservationIgnored private var purchasesKey: String
    @ObservationIgnored private var itemDetails: [String: AdminMarketplaceItemDetailViewModel] = [:]

    var searchText = ""
    /// nil = tutti i tipi.
    var kind: AdminMarketplaceKind?
    var area: AdminMarketplaceArea?
    var ownershipFilter: AdminMarketplaceOwnershipFilter = .all
    /// Le faccette dei full set (macchina, costruttore, settore): restringono solo loro, come sulla web.
    var machineType: String?
    var manufacturer: String?
    var industry: String?
    /// Il form della chiave MaintainX aperto dalla barra (quando MaintainX non è nella lista).
    var maintainXForm: AdminConnectorCredentialsFormViewModel?

    private let purchaseDefaults: UserDefaults

    /// Senza `catalog` il catalogo del bundle si legge al primo `load()`, fuori dal main actor.
    init(backend: AriaBackend, catalog: [AdminMarketplaceItem]? = nil, purchaseDefaults: UserDefaults = .standard) {
        self.backend = backend
        self.purchaseDefaults = purchaseDefaults
        if let catalog {
            index = AdminMarketplaceIndex(catalog: catalog)
            isCatalogReady = true
        } else {
            index = .empty
            isCatalogReady = false
        }
        purchasesKey = backend.activeCompanyId ?? "-"
        purchases = AdminMarketplacePurchases(companyId: backend.activeCompanyId, defaults: purchaseDefaults).load()
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

    // MARK: Catalogo

    func item(id: String) -> AdminMarketplaceItem? { index.itemsByID[id] }

    /// Nell'ordine dato; gli id che il catalogo non conosce (un tipo nuovo della web) si saltano.
    func items(ids: [String]) -> [AdminMarketplaceItem] { ids.compactMap { index.itemsByID[$0] } }

    /// Dove sta l'elemento per questa azienda: incluso nel piano, comprato (da solo o dentro un pacchetto,
    /// o un connettore collegato) oppure in vendita, come `ownership` di pricing.ts.
    func ownership(of item: AdminMarketplaceItem) -> AdminMarketplaceOwnership {
        if item.isIncluded { return .included }
        if purchases.contains(item.id) || isConnectedConnector(item) { return .purchased }
        if index.bundledIn[item.id]?.contains(where: purchases.contains) == true { return .purchased }
        return .forSale
    }

    /// Una riga del server in stato collegato.
    func isConnected(_ provider: String) -> Bool { connector(for: provider)?.knownStatus == .connected }

    func hasServerConnector(_ provider: String) -> Bool { connector(for: provider) != nil }

    /// Il nome del catalogo, altrimenti quello del server, altrimenti uno ricavato dallo slug.
    func connectorName(_ provider: String) -> String {
        index.connectorItems[provider]?.name ?? connector(for: provider)?.name ?? AdminConnector.prettyName(provider)
    }

    /// Lo stato grezzo della riga del server per un connettore del catalogo; nil per ogni altro elemento.
    func serverStatus(for item: AdminMarketplaceItem) -> String? {
        item.kind == .connector ? connector(for: item.sourceId)?.status : nil
    }

    /// Un connettore con integrazione dietro non si compra mai (è "in arrivo"); gli altri solo se in vendita.
    func canBuy(_ item: AdminMarketplaceItem) -> Bool {
        canManage && ownership(of: item) == .forSale && !item.isPreview
    }

    /// Registra l'acquisto su questo telefono (non c'è fatturazione né rotta del backend).
    func purchase(_ item: AdminMarketplaceItem) {
        syncPurchases()
        guard canBuy(item) else { return }
        purchases.insert(item.id)
        AdminMarketplacePurchases(companyId: backend.activeCompanyId, defaults: purchaseDefaults).save(purchases)
    }

    /// Un connettore che il server conosce va al suo dettaglio vero; ogni altro alla pagina del catalogo.
    func route(for item: AdminMarketplaceItem) -> AdminMarketplaceRoute {
        item.kind == .connector && hasServerConnector(item.sourceId) ? .connector(item.sourceId) : .item(item.id)
    }

    /// Uno per elemento e tenuto: la destinazione si ricalcola a ogni cambio della lista, e un VM nuovo
    /// perderebbe l'avviso d'acquisto aperto.
    func makeItemDetailViewModel(for id: String) -> AdminMarketplaceItemDetailViewModel? {
        if let cached = itemDetails[id] { return cached }
        guard let found = item(id: id) else { return nil }
        let detail = AdminMarketplaceItemDetailViewModel(item: found, marketplace: self)
        itemDetails[id] = detail
        return detail
    }

    private func isConnectedConnector(_ item: AdminMarketplaceItem) -> Bool {
        item.kind == .connector && isConnected(item.sourceId)
    }

    /// Posseduto = connettore collegato o acquisto; l'incluso non usato non conta.
    private func isOwned(_ item: AdminMarketplaceItem) -> Bool {
        isConnectedConnector(item) || ownership(of: item) == .purchased
    }

    // MARK: Acquisti

    /// Gli acquisti sono per azienda: cambiata quella attiva si rileggono i suoi.
    private func syncPurchases() {
        guard purchasesKey != loadKey else { return }
        purchasesKey = loadKey
        purchases = AdminMarketplacePurchases(companyId: backend.activeCompanyId, defaults: purchaseDefaults).load()
    }

    // MARK: Filtri

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Le faccette si offrono (e valgono) solo guardando tutto o i full set.
    var showsMachineFacets: Bool {
        (kind == nil || kind == .fullSet) && catalog.contains { $0.kind == .fullSet }
    }

    private var hasFacetFilter: Bool {
        showsMachineFacets && (machineType != nil || manufacturer != nil || industry != nil)
    }

    var hasActiveFilters: Bool { !activeFilters.isEmpty }

    var activeFilters: [AdminMarketplaceActiveFilter] {
        var filters: [AdminMarketplaceActiveFilter] = []
        if let area { filters.append(.init(kind: .area, title: area.label)) }
        if ownershipFilter != .all { filters.append(.init(kind: .ownership, title: ownershipFilter.label)) }
        if showsMachineFacets {
            if let machineType { filters.append(.init(kind: .machineType, title: machineType)) }
            if let manufacturer { filters.append(.init(kind: .manufacturer, title: manufacturer)) }
            if let industry { filters.append(.init(kind: .industry, title: industry)) }
        }
        return filters
    }

    func remove(_ filter: AdminMarketplaceActiveFilter) {
        switch filter.kind {
        case .area: area = nil
        case .ownership: ownershipFilter = .all
        case .machineType: machineType = nil
        case .manufacturer: manufacturer = nil
        case .industry: industry = nil
        }
    }

    /// Toglie area, possesso e faccette; la ricerca e il tipo restano.
    func clearFilters() {
        area = nil
        ownershipFilter = .all
        clearFacets()
    }

    /// Cambia tipo: le faccette dei full set non hanno senso sugli altri, si azzerano.
    func select(kind newKind: AdminMarketplaceKind?) {
        kind = newKind
        if newKind != nil, newKind != .fullSet { clearFacets() }
    }

    private func clearFacets() {
        machineType = nil
        manufacturer = nil
        industry = nil
    }

    private enum Facet { case machineType, manufacturer, industry }

    private func matchesSearch(_ item: AdminMarketplaceItem) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return index.searchIndex[item.id]?.contains { $0.localizedStandardContains(query) } ?? false
    }

    /// Le faccette valgono per i full set; uno senza macchina non passa se ce n'è una scelta.
    private func matchesFacets(_ item: AdminMarketplaceItem, ignoring skipped: Facet?) -> Bool {
        guard showsMachineFacets, item.kind == .fullSet else { return true }
        let wanted: [(Facet, String?, String?)] = [
            (.machineType, machineType, item.machine?.type),
            (.manufacturer, manufacturer, item.machine?.manufacturer),
            (.industry, industry, item.machine?.industry),
        ]
        return wanted.allSatisfy { facet, chosen, actual in
            guard facet != skipped, let chosen else { return true }
            return chosen == actual
        }
    }

    /// `ignoringKind` per i conteggi del selettore; `skipped` per le opzioni di una faccetta (contate sulle altre).
    private func passes(_ item: AdminMarketplaceItem, ignoringKind: Bool = false, skipping skipped: Facet? = nil) -> Bool {
        if !ignoringKind, let kind, item.kind != kind { return false }
        if let area, item.area != area { return false }
        guard matchesSearch(item) else { return false }
        switch ownershipFilter {
        case .all: break
        case .owned: if !isOwned(item) { return false }
        case .available: if isOwned(item) { return false }
        }
        return matchesFacets(item, ignoring: skipped)
    }

    // MARK: Connettori fuori catalogo

    /// I connettori del server che il catalogo non ha (personalizzati, orfani, ritirati): restano visibili come
    /// schede dei connettori. Cercati per nome, mai con area o faccette (non ne hanno).
    var extraServerConnectors: [AdminConnector] { extras(ignoringKind: false) }

    private func extras(ignoringKind: Bool) -> [AdminConnector] {
        guard ignoringKind || kind == nil || kind == .connector, area == nil, !hasFacetFilter else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return connectors
            .filter { index.connectorItems[$0.provider] == nil }
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) || $0.provider.localizedStandardContains(query) }
            .filter {
                switch ownershipFilter {
                case .all: true
                case .owned: $0.knownStatus == .connected
                case .available: $0.knownStatus != .connected
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: Scaffali

    /// Con "Tutti" uno scaffale per tipo, con un tipo scelto uno per area; i vuoti si saltano.
    var shelves: [AdminMarketplaceShelf] {
        let visible = catalog.filter { passes($0) }
        let extra = extras(ignoringKind: false)
        if kind == nil {
            let byKind = Dictionary(grouping: visible, by: \.kind)
            return AdminMarketplaceKind.allCases.compactMap { kind in
                let items = Self.sorted(byKind[kind] ?? [])
                let extraConnectors = kind == .connector ? extra : []
                guard !items.isEmpty || !extraConnectors.isEmpty else { return nil }
                return AdminMarketplaceShelf(id: "kind:\(kind.rawValue)", title: kind.plural, blurb: kind.blurb,
                                             items: items, extraConnectors: extraConnectors)
            }
        }
        let byArea = Dictionary(grouping: visible, by: \.area)
        var result = AdminMarketplaceArea.allCases.compactMap { area -> AdminMarketplaceShelf? in
            let items = Self.sorted(byArea[area] ?? [])
            guard !items.isEmpty else { return nil }
            return AdminMarketplaceShelf(id: "area:\(area.rawValue)", title: area.label, blurb: area.blurb, items: items)
        }
        if !extra.isEmpty {
            result.append(AdminMarketplaceShelf(id: "extra", title: String(localized: "Other connectors"),
                                                blurb: String(localized: "Set up on your server, not in the catalog."),
                                                items: [], extraConnectors: extra))
        }
        return result
    }

    /// Le novità prima, poi per nome.
    private static func sorted(_ items: [AdminMarketplaceItem]) -> [AdminMarketplaceItem] {
        items.sorted {
            if $0.isNew != $1.isNew { return $0.isNew }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    // MARK: Selettore di tipo

    /// "Tutti" e un chip per tipo, con quanti elementi ci sono ignorando il tipo scelto.
    var kindChips: [AdminMarketplaceKindChip] {
        var counts: [AdminMarketplaceKind: Int] = [:]
        for item in catalog where passes(item, ignoringKind: true) { counts[item.kind, default: 0] += 1 }
        counts[.connector, default: 0] += extras(ignoringKind: true).count
        let total = counts.values.reduce(0, +)
        let all = AdminMarketplaceKindChip(kind: nil, title: String(localized: "All"), count: total, isSelected: kind == nil)
        return [all] + AdminMarketplaceKind.allCases.map { kindCase in
            AdminMarketplaceKindChip(kind: kindCase, title: kindCase.plural, count: counts[kindCase] ?? 0,
                                     isSelected: kind == kindCase)
        }
    }

    // MARK: Faccette dei full set

    var machineTypeOptions: [AdminMarketplaceFacetOption] { options(for: .machineType, selected: machineType) { $0.type } }
    var manufacturerOptions: [AdminMarketplaceFacetOption] { options(for: .manufacturer, selected: manufacturer) { $0.manufacturer } }
    var industryOptions: [AdminMarketplaceFacetOption] { options(for: .industry, selected: industry) { $0.industry } }

    /// I valori presenti nei full set, contati contro le altre faccette (`facetOptions` della web); il valore
    /// scelto resta in lista anche a zero, per poterlo togliere.
    private func options(for facet: Facet, selected: String?,
                         value: (AdminMarketplaceItem.Machine) -> String) -> [AdminMarketplaceFacetOption] {
        var counts: [String: Int] = [:]
        for item in catalog where item.kind == .fullSet {
            guard let machine = item.machine, passes(item, ignoringKind: true, skipping: facet) else { continue }
            counts[value(machine), default: 0] += 1
        }
        if let selected, counts[selected] == nil { counts[selected] = 0 }
        return counts
            .map { AdminMarketplaceFacetOption(value: $0.key, count: $0.value) }
            .sorted { $0.value.localizedStandardCompare($1.value) == .orderedAscending }
    }

    // MARK: Riepilogo

    var connectedCount: Int { connectors.filter { $0.knownStatus == .connected }.count }
    var attentionCount: Int { connectors.filter { $0.knownStatus == .attention }.count }
    var toolCount: Int { connectors.filter { $0.knownStatus == .connected }.reduce(0) { $0 + $1.toolCount } }
    /// Gli elementi del catalogo che l'azienda possiede: connettori collegati e acquisti.
    var ownedCount: Int { catalog.filter(isOwned).count }

    /// MaintainX si collega con una chiave anche quando il server non lo elenca.
    var canAddMaintainX: Bool { canManage && !connectors.contains(where: \.isMaintainX) }

    func connector(for provider: String) -> AdminConnector? {
        connectors.first { $0.provider == provider }
    }

    // MARK: Caricamento

    /// Legge il catalogo del bundle una volta, fuori dal main actor; poi gli indici restano.
    private func ensureCatalog() async {
        guard !isCatalogReady else { return }
        let loaded = await AdminMarketplaceCatalog.loadIndex()
        guard !isCatalogReady else { return }
        index = loaded
        isCatalogReady = true
    }

    func load() async {
        await ensureCatalog()
        // Altra azienda: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        let key = loadKey
        if key != loadedKey {
            connectors = []
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        syncPurchases()
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
        kind = nil
        clearFilters()
        maintainXForm = nil
        itemDetails = [:]
    }
}
