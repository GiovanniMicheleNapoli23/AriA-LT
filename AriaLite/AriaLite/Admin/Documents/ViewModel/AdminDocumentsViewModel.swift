//
//  AdminDocumentsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La libreria documenti dell'azienda, come la pagina /knowledge della web.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//  Lo stabilimento si chiede al server; stato e ricerca filtrano qui sui documenti scaricati.
//  Finché un documento è in elaborazione la lista si riaggiorna da sola (4, 8, 15, 30 s: AdminDocumentPollSchedule),
//  ma non con un dettaglio aperto sopra (si aggiorna lui e passa le novità alla lista), non con l'app non attiva
//  e non senza rete. Rientrando nella sezione la lista si rilegge solo se ha più di 45 s.
//  I caricamenti (AdminDocumentUploadCenter) vivono qui: continuano a foglio chiuso e app in background.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminDocumentsViewModel {
    let backend: AriaBackend
    /// I file in caricamento, con la loro barra.
    let uploads: AdminDocumentUploadCenter

    static let pageSize = 50
    private(set) var documents: [AdminDocument] = []
    /// Quanti sono sul server con questi filtri, se lo dice.
    private(set) var total: Int?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    /// L'ultima pagina era piena: forse ce ne sono altre (quando `total` manca).
    private var lastPageWasFull = false
    @ObservationIgnored private var loadedKey: String?
    @ObservationIgnored private var reloadTask: Task<Void, Never>?
    /// Da quando la lista a schermo è fresca: rientrando prima la sezione non la richiede.
    @ObservationIgnored private var freshness = AriaFreshness()
    @ObservationIgnored let network: AriaNetworkMonitor

    /// La vista dice se un dettaglio è aperto sopra la lista (lì si aggiorna lui) e se l'app è attiva:
    /// in entrambi i casi il ciclo di aggiornamento della lista sta fermo.
    var isDetailOpen = false
    var isAppActive = true
    /// Cresce a ogni lettura forzata: un ciclo fermo per troppa calma riparte.
    private(set) var pollEpoch = 0

    var searchText = ""
    var statusFilter: AdminDocumentStatusGroup?
    private var plantChoice: PlantChoice = .active

    /// Cancellazione chiesta dalla lista (menu contestuale), in attesa di conferma.
    var documentToDelete: AdminDocument?
    var showsDeleteConfirmation = false
    private(set) var actionError: String?
    var showsActionError = false

    private enum PlantChoice: Equatable {
        /// Lo stabilimento attivo dell'app (cambia con lui).
        case active
        case all
        case plant(String)
    }

    init(backend: AriaBackend, network: AriaNetworkMonitor = .shared) {
        self.backend = backend
        self.network = network
        uploads = AdminDocumentUploadCenter(backend: backend)
        uploads.onUploaded = { [weak self] in
            self?.scheduleReload()
            self?.backend.usage.refreshAllowanceLater()
        }
        // Ritrova subito i caricamenti lasciati dall'esecuzione precedente.
        Task { [uploads] in await uploads.start() }
    }

    /// Cambia quando va richiesta la lista: azienda o stabilimento.
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(plantId ?? "*")" }

    /// Cambia quando parte o finisce un'elaborazione: la vista ci appende il ciclo di aggiornamento.
    var pollKey: String { "\(loadKey)|\(hasProcessing)|\(canPoll)|\(pollEpoch)" }

    /// Il ciclo di aggiornamento può girare: nessun dettaglio sopra e app attiva.
    var canPoll: Bool { !isDetailOpen && isAppActive }

    // MARK: Filtri

    /// Lo stabilimento richiesto al server; `nil` = tutti.
    var plantId: String? {
        switch plantChoice {
        case .active: backend.activePlantId
        case .all: nil
        case .plant(let id): id
        }
    }

    /// Per il Picker: `nil` = tutti gli stabilimenti.
    var selectedPlantId: String? {
        get { plantId }
        set { plantChoice = newValue.map(PlantChoice.plant) ?? .all }
    }

    var plants: [AriaPlant] { backend.plants }

    var plantFilterLabel: String {
        guard let plantId else { return String(localized: "All sites") }
        return plants.first { $0.id == plantId }?.name ?? String(localized: "This site")
    }

    /// Lo stabilimento filtrato non è quello attivo dell'app: il filtro si evidenzia.
    var isPlantFilterCustom: Bool { plantId != backend.activePlantId }

    var statusFilterLabel: String { statusFilter?.label ?? String(localized: "All") }

    var visibleDocuments: [AdminDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return documents
            .filter { statusFilter == nil || $0.statusGroup == statusFilter }
            .filter { query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(query) } }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func clearFilters() { statusFilter = nil }

    // MARK: Riepilogo

    var hasProcessing: Bool { documents.contains(where: \.isProcessing) }

    func count(_ group: AdminDocumentStatusGroup) -> Int {
        documents.count { $0.statusGroup == group }
    }

    var subtitle: String {
        let shown = visibleDocuments.count
        if let total, statusFilter == nil, !isSearching, total > shown {
            return String(localized: "\(shown) of \(total) documents")
        }
        return String(localized: "\(shown) documents")
    }

    var canLoadMore: Bool {
        guard hasLoaded else { return false }
        if let total { return documents.count < total }
        return lastPageWasFull
    }

    // MARK: Caricamento

    /// All'entrata nella sezione: legge se mai letta, se è cambiato il contesto o se la lista ha più di 45 s.
    /// Con la lista già a schermo l'aggiornamento è silenzioso (`load` non svuota niente).
    func loadIfNeeded() async {
        guard !hasLoaded || loadedKey != loadKey || freshness.isStale() else { return }
        await load()
    }

    /// Lettura forzata: tirare per aggiornare, "Riprova", dopo un caricamento.
    func load() async {
        pollEpoch += 1
        guard let companyId = backend.activeCompanyId else {
            errorMessage = String(localized: "Choose a company first.")
            return
        }
        let key = loadKey
        // Altra azienda o altro stabilimento: la lista vecchia non vale, non si mostra mentre arriva la nuova.
        if key != loadedKey {
            freshness.invalidate()
            documents = []
            total = nil
            hasLoaded = false
            errorMessage = nil
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await backend.api.call(AdminDocumentsAPI.documents(
                companyId: companyId, plantId: plantId, skip: 0, limit: Self.pageSize))
            guard key == loadKey, !Task.isCancelled else { return }
            documents = page.items.filter { !$0.isDeleted }
            total = page.total
            lastPageWasFull = page.items.count >= Self.pageSize
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
            freshness.markLoaded()
        } catch {
            freshness.invalidate()
            guard key == loadKey, let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore, let companyId = backend.activeCompanyId else { return }
        let key = loadKey
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await backend.api.call(AdminDocumentsAPI.documents(
                companyId: companyId, plantId: plantId, skip: documents.count, limit: Self.pageSize))
            guard key == loadKey else { return }
            let known = Set(documents.map(\.id))
            documents += page.items.filter { !known.contains($0.id) && !$0.isDeleted }
            total = page.total ?? total
            lastPageWasFull = page.items.count >= Self.pageSize
        } catch {
            guard key == loadKey, let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    /// Gli stati di tutti i documenti a schermo: se cambiano, è successo qualcosa e il ritmo riparte veloce.
    private var statusSignature: [String] {
        documents.map { "\($0.id)|\($0.ingestionState ?? "")|\($0.extractionState ?? "")" }
    }

    /// Finché qualcosa è in elaborazione, riaggiorna in silenzio (niente spinner, niente errori a schermo),
    /// con attese crescenti (AdminDocumentPollSchedule). Senza rete salta il giro. Si ferma da solo quando tutto è
    /// finito, la vista sparisce, un dettaglio si apre sopra, l'app non è attiva o per troppo tempo non cambia niente.
    func pollWhileProcessing() async {
        var schedule = AdminDocumentPollSchedule()
        while hasProcessing, canPoll, !schedule.isExhausted, !Task.isCancelled {
            do { try await Task.sleep(for: schedule.delay) } catch { return }
            // Offline: nessuna richiesta e nessun rallentamento, si riprova al giro dopo.
            guard network.isOnline else { continue }
            let before = statusSignature
            await refreshSilently()
            schedule.recordTick(changed: statusSignature != before)
        }
    }

    /// Di ritorno nell'app: la lista si riallinea subito, senza aspettare il prossimo giro.
    func refreshOnReturn() async {
        await refreshSilently()
    }

    /// Riprende le prime pagine (fino a 100 documenti) e le sostituisce; quelli oltre restano.
    private func refreshSilently() async {
        guard let companyId = backend.activeCompanyId, hasLoaded else { return }
        let key = loadKey
        let limit = min(max(documents.count, Self.pageSize), AdminDocumentsAPI.maxPage)
        guard let page = try? await backend.api.call(AdminDocumentsAPI.documents(
            companyId: companyId, plantId: plantId, skip: 0, limit: limit)) else { return }
        guard key == loadKey, !Task.isCancelled else { return }
        let fresh = Set(page.items.map(\.id))
        let tail = documents.count > limit ? documents[limit...].filter { !fresh.contains($0.id) } : []
        documents = page.items.filter { !$0.isDeleted } + tail
        total = page.total ?? total
        lastUpdated = .now
        freshness.markLoaded()
    }

    // MARK: Dopo una modifica

    /// Un documento aggiornato dal dettaglio: si sostituisce senza ricaricare.
    func apply(_ document: AdminDocument) {
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index] = document
        }
    }

    func remove(id: String) {
        documents.removeAll { $0.id == id }
        total = total.map { max($0 - 1, 0) }
    }

    // MARK: Cancellazione dalla lista

    func askDelete(_ document: AdminDocument) {
        documentToDelete = document
        showsDeleteConfirmation = true
    }

    func delete(_ document: AdminDocument, removingExtractedData: Bool) async {
        do {
            _ = try await backend.api.call(AdminDocumentsAPI.delete(id: document.id, rollbackEntities: removingExtractedData))
            remove(id: document.id)
            backend.usage.refreshAllowanceLater()
        } catch {
            guard let message = AdminDocumentsFailure.message(for: error, backend: backend) else { return }
            actionError = message
            showsActionError = true
        }
        documentToDelete = nil
    }

    // MARK: Altre schermate

    func makeDetailViewModel(for document: AdminDocument) -> AdminDocumentDetailViewModel {
        AdminDocumentDetailViewModel(backend: backend, document: document, network: network,
                                     onChange: { [weak self] in self?.apply($0) },
                                     onDelete: { [weak self] in self?.remove(id: $0) })
    }

    func makeUploadViewModel() -> AdminDocumentUploadViewModel {
        AdminDocumentUploadViewModel(backend: backend, plantId: plantId ?? backend.activePlantId, uploads: uploads)
    }

    /// Il foglio di caricamento si è chiuso: i file scelti e non affidati non servono più.
    func uploadSheetClosed() {
        uploads.discardUnsentFiles()
    }

    /// Dopo un caricamento: la lista si ricarica e il ciclo di aggiornamento segue l'elaborazione.
    /// Più file finiti insieme fanno una ricarica sola.
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.load()
        }
    }

    /// Il caricamento vuole un'azienda e uno stabilimento.
    var canUpload: Bool { Self.canUpload(backend) }

    /// Lo stesso conto per chi non ha il view model (il giro guidato): niente sito, niente caricamento.
    static func canUpload(_ backend: AriaBackend) -> Bool {
        backend.activeCompanyId != nil && (backend.activePlantId != nil || !backend.plants.isEmpty)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        reloadTask?.cancel()
        uploads.reset()
        documents = []
        total = nil
        isLoading = false
        isLoadingMore = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        lastPageWasFull = false
        loadedKey = nil
        freshness.invalidate()
        isDetailOpen = false
        searchText = ""
        statusFilter = nil
        plantChoice = .active
        documentToDelete = nil
        showsDeleteConfirmation = false
        actionError = nil
        showsActionError = false
    }
}
