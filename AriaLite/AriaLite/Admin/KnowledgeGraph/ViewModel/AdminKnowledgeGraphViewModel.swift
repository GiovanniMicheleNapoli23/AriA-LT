//
//  AdminKnowledgeGraphViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Knowledge Graph, come la pagina /knowledge-graph della web, ma da esplorare invece che
//  da trascinare: le liste dell'azienda si scaricano insieme e diventano un grafo (AdminKnowledgeGraphIndex).
//  Una lista che fallisce (es. 403) spegne solo la sua casella. Vive in AppViewModel.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminKnowledgeGraphViewModel {
    typealias Kind = AdminKnowledgeGraphKind
    typealias Ref = AdminKnowledgeGraphRef

    let backend: AriaBackend

    private(set) var index = AdminKnowledgeGraphIndex()
    /// I tipi arrivati almeno una volta per l'azienda a schermo.
    private(set) var loadedKinds: Set<Kind> = []
    /// Perché un tipo non c'è (ruolo, errore); si cancella quando arriva.
    private(set) var failures: [Kind: String] = [:]
    /// Il totale dei documenti sul server (se ne scaricano al massimo `maxDocumentPages` pagine).
    private(set) var documentTotal: Int?
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    /// Gli asset con più collegamenti: da lì conviene partire (si calcolano una volta per caricamento).
    private(set) var hubs: [AdminKnowledgeGraphNodeLinks] = []
    @ObservationIgnored private var loadedKey: String?

    var searchText = ""
    /// Ricerca dentro la lista di un tipo, una per tipo.
    private var listQueries: [Kind: String] = [:]
    /// L'ultima ricerca globale già portata nella lista di ogni tipo.
    @ObservationIgnored private var carriedSearch: [Kind: String] = [:]

    // Elaborazioni dei documenti, per chiave del documento: si chiedono all'apertura del dettaglio.
    private(set) var runsByDocument: [String: [AdminKnowledgeGraphDocumentRun]] = [:]
    private(set) var runErrors: [String: String] = [:]
    private(set) var loadingRuns: Set<String> = []

    nonisolated private static let maxDocumentPages = 3

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va riscaricato il grafo: un'altra azienda.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    // MARK: Panoramica

    var hasLoaded: Bool { !loadedKinds.isEmpty }

    /// Nessuna lista è arrivata e almeno una ha detto perché: si mostra l'errore a tutta pagina.
    var blockingError: String? {
        guard loadedKinds.isEmpty, !isLoading else { return nil }
        let remote = Kind.allCases.filter { $0 != .plant }
        guard remote.allSatisfy({ failures[$0] != nil }) else { return nil }
        // Se il motivo è lo stesso per tutte, si dice una volta; altrimenti il primo.
        return failures[.asset] ?? failures.values.first
    }

    var tiles: [AdminKnowledgeGraphTile] {
        Kind.allCases.map { kind in
            if loadedKinds.contains(kind) {
                let count = kind == .document ? max(documentTotal ?? 0, index.nodes(of: kind).count) : index.nodes(of: kind).count
                return AdminKnowledgeGraphTile(kind: kind, state: .count(count))
            }
            if let message = failures[kind] { return AdminKnowledgeGraphTile(kind: kind, state: .unavailable(message)) }
            return AdminKnowledgeGraphTile(kind: kind, state: .loading)
        }
    }

    var summary: String {
        let entities = index.entityCount
        let links = index.linkCount
        return String(localized: "\(entities) entities · \(links) links")
    }


    /// Le liste che non sono arrivate, per la nota sotto le caselle.
    var unavailableKinds: [Kind] { Kind.allCases.filter { failures[$0] != nil && !loadedKinds.contains($0) } }

    /// L'ultimo aggiornamento di qualche lista già a schermo è fallito: si mostrano i dati precedenti.
    var hasStaleKinds: Bool { failures.keys.contains { loadedKinds.contains($0) } }

    // MARK: Ricerca

    var isSearching: Bool { !query(searchText).isEmpty }

    /// I nodi che contengono il testo cercato, raggruppati per tipo (i primi `limit` per gruppo).
    var searchResults: [AdminKnowledgeGraphRelationGroup] {
        let text = query(searchText)
        guard !text.isEmpty else { return [] }
        return Kind.allCases.compactMap { kind in
            let nodes = matches(index.nodes(of: kind), text)
            return nodes.isEmpty ? nil : AdminKnowledgeGraphRelationGroup(kind: kind, nodes: nodes)
        }
    }

    func listQuery(for kind: Kind) -> String { listQueries[kind] ?? "" }
    func setListQuery(_ text: String, for kind: Kind) { listQueries[kind] = text }

    /// La lista di un tipo aperta dai risultati della ricerca globale parte con la stessa ricerca.
    /// Una volta per testo: se poi la ricerca della lista si svuota a mano, tornando indietro resta vuota.
    func listAppeared(_ kind: Kind) {
        let text = query(searchText)
        guard !text.isEmpty, carriedSearch[kind] != text else { return }
        carriedSearch[kind] = text
        listQueries[kind] = text
    }

    func nodes(of kind: Kind) -> [AdminKnowledgeGraphNode] {
        let text = query(listQuery(for: kind))
        let nodes = index.nodes(of: kind)
        return text.isEmpty ? nodes : matches(nodes, text)
    }

    func listSubtitle(for kind: Kind) -> String {
        let shown = nodes(of: kind).count
        if kind == .document, let total = documentTotal, total > index.nodes(of: kind).count, query(listQuery(for: kind)).isEmpty {
            return String(localized: "\(shown) of \(total) documents, most recent first")
        }
        return String(localized: "\(shown) results")
    }

    private func query(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func matches(_ nodes: [AdminKnowledgeGraphNode], _ text: String) -> [AdminKnowledgeGraphNode] {
        nodes.filter { node in ([node.title] + node.searchable).contains { $0.localizedStandardContains(text) } }
    }

    // MARK: Dettaglio

    func node(for ref: Ref) -> AdminKnowledgeGraphNode? { index.node(for: ref) }
    func relations(of ref: Ref) -> [AdminKnowledgeGraphRelationGroup] { index.relations(of: ref) }
    func fields(of ref: Ref) -> [AdminAssetField] { index.fields(of: ref) }
    func texts(of ref: Ref) -> [AdminKnowledgeGraphTextBlock] { index.texts(of: ref) }

    func related(_ kind: Kind, of ref: Ref) -> [AdminKnowledgeGraphNode] {
        relations(of: ref).first { $0.kind == kind }?.nodes ?? []
    }

    /// Il riepilogo sotto il titolo: quanti collegamenti ha l'entità.
    func linkSummary(for ref: Ref) -> String {
        let count = relations(of: ref).reduce(0) { $0 + $1.nodes.count }
        return String(localized: "\(count) linked entities")
    }

    /// Il tipo che nessuno potrà mai collegare: lo si dice invece di mostrare un vuoto muto.
    func missingRelationsNote(for ref: Ref) -> String? {
        guard relations(of: ref).isEmpty else { return nil }
        if ref.kind == .document {
            return String(localized: "Documents are linked to assets through their tags. Tag this document with an asset tag to connect it.")
        }
        return String(localized: "No links to other entities yet.")
    }

    // MARK: Elaborazioni dei documenti

    func runs(for ref: Ref) -> [AdminKnowledgeGraphDocumentRun] { runsByDocument[ref.key] ?? [] }
    func runError(for ref: Ref) -> String? { runErrors[ref.key] }
    func isLoadingRuns(for ref: Ref) -> Bool { loadingRuns.contains(ref.key) }

    /// "Completed · Ingestion": stato e tipo di elaborazione.
    func runTitle(_ run: AdminKnowledgeGraphDocumentRun) -> String {
        let state = AdminKnowledgeGraphKey.humanized(run.state) ?? String(localized: "Run")
        return AdminKnowledgeGraphIndex.line([state, AdminKnowledgeGraphKey.humanized(run.pipelineType)]) ?? state
    }

    /// Cosa ha prodotto: pezzi indicizzati, entità estratte, classificazione, modello.
    func runSummary(_ run: AdminKnowledgeGraphDocumentRun) -> String? {
        AdminKnowledgeGraphIndex.line([
            run.chunksCreated.map { String(localized: "\($0) chunks") },
            run.entitiesExtracted.map { String(localized: "\($0) entities extracted") },
            run.classification.isEmpty ? nil : run.classification.joined(separator: ", "),
            run.model,
        ])
    }

    /// All'apertura del dettaglio: per un documento si chiedono le elaborazioni.
    func detailAppeared(_ ref: Ref) async {
        guard ref.kind == .document, let documentId = index.documents[ref.key]?.serverId else { return }
        loadingRuns.insert(ref.key)
        defer { loadingRuns.remove(ref.key) }
        do {
            let page = try await backend.api.call(AdminKnowledgeGraphAPI.documentRuns(documentId: documentId))
            runsByDocument[ref.key] = page.items.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            runErrors[ref.key] = nil
        } catch {
            guard let message = AdminKnowledgeGraphFailure.message(for: error, backend: backend) else { return }
            runErrors[ref.key] = message
        }
    }

    // MARK: Caricamento

    /// Tutte le liste insieme; ciascuna può fallire da sola.
    func load() async {
        let key = loadKey
        if key != loadedKey {
            // Altra azienda: il grafo vecchio non vale, non si mostra mentre arriva il nuovo.
            clearGraph()
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }

        let api = backend.api
        let companyId = backend.activeCompanyId
        async let assets = Self.attempt { try await api.call(AdminAssetsAPI.assets(status: nil)).items }
        async let alarms = Self.attempt { try await api.call(AdminKnowledgeGraphAPI.alarms()).items }
        async let plans = Self.attempt { try await api.call(AdminKnowledgeGraphAPI.maintenancePlans()).items }
        async let parts = Self.attempt { try await AdminSparePartsAPI(api: api).list(plantId: nil) }
        async let orders = Self.attempt { try await api.call(AdminKnowledgeGraphAPI.workOrders()).items }
        async let documents = Self.attempt { try await Self.documents(api: api, companyId: companyId) }
        let results = await (assets, alarms, plans, parts, orders, documents)

        // Un'altra azienda è stata scelta durante il caricamento: questi dati non valgono più.
        guard key == loadKey, !Task.isCancelled else { return }
        var data = index.data
        apply(results.0, to: .asset) { data.assets = $0 }
        apply(results.1, to: .alarm) { data.alarms = $0 }
        apply(results.2, to: .maintenancePlan) { data.plans = $0 }
        apply(results.3, to: .sparePart) { data.parts = $0 }
        apply(results.4, to: .workOrder) { data.workOrders = $0 }
        apply(results.5, to: .document) { page in
            data.documents = page.items
            documentTotal = page.total
        }
        // Gli stabilimenti li ha già GET /v1/plants del backend.
        data.plants = backend.plants
        loadedKinds.insert(.plant)
        index = AdminKnowledgeGraphIndex(data: data)
        hubs = index.hubs(of: .asset, limit: 5).map { AdminKnowledgeGraphNodeLinks(node: $0.node, links: $0.links) }
        lastUpdated = .now
    }

    private func apply<T>(_ result: Result<T, any Error>, to kind: Kind, _ store: (T) -> Void) {
        switch result {
        case .success(let value):
            store(value)
            loadedKinds.insert(kind)
            failures[kind] = nil
        case .failure(let error):
            // Annullata: resta quello che c'era. Altrimenti si dice perché; i dati vecchi restano se c'erano.
            guard let message = AdminKnowledgeGraphFailure.message(for: error, backend: backend) else { return }
            failures[kind] = message
        }
    }

    nonisolated private static func attempt<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, any Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    /// Le prime pagine dei documenti (100 l'una), finché il server ne ha.
    nonisolated private static func documents(api: AriaAPIClient, companyId: String?) async throws -> (items: [AdminKnowledgeGraphDocument], total: Int?) {
        // Senza azienda scelta non c'è niente da chiedere (la rotta vuole `company_id`).
        guard let companyId else { return ([], 0) }
        var items: [AdminKnowledgeGraphDocument] = []
        var total: Int?
        for _ in 0..<maxDocumentPages {
            let page = try await api.call(AdminKnowledgeGraphAPI.documents(companyId: companyId, skip: items.count))
            items += page.items
            total = page.total ?? total
            guard !page.items.isEmpty, items.count < (total ?? 0) else { break }
        }
        return (items, total)
    }

    private func clearGraph() {
        index = AdminKnowledgeGraphIndex()
        hubs = []
        loadedKinds = []
        failures = [:]
        documentTotal = nil
        lastUpdated = nil
        runsByDocument = [:]
        runErrors = [:]
        loadingRuns = []
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        clearGraph()
        isLoading = false
        loadedKey = nil
        searchText = ""
        listQueries = [:]
        carriedSearch = [:]
    }
}
