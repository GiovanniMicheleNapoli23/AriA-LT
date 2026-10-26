//
//  AdminCraftedViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  La sezione Crafted, come la pagina /crafted della web: una sola lista con i rapporti d'intervento (da
//  session-reviews) e quello che Aria ha fatto su richiesta (dallo store sul dispositivo). Qui lo stato e il
//  caricamento; la lista pronta per la vista è in +Library, le azioni (aprire, eliminare, comporre) in +Actions.
//  Vive in AppViewModel: i dati e le generazioni in corso restano fra un cambio di sezione e l'altro.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedViewModel {
    let backend: AriaBackend

    var searchText = ""
    /// La categoria scelta nel filtro; nil = tutte.
    var category: AdminCraftedCategory?
    var sort: AdminCraftedSort = .recent
    /// Le schermate aperte sopra la lista (lettori di artifact e di rapporti).
    var path: [AdminCraftedItem] = [] {
        didSet { pruneReaders() }
    }
    /// Il composer ("Cosa vuoi che Aria crei?"), in un foglio finché non è nil.
    var composer: AdminCraftedComposerViewModel?

    private(set) var reviews: [AdminCraftedSessionReview] = []
    private(set) var reviewsLoaded = false
    private(set) var reviewsNote: AdminCraftedReviewsNote?
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?

    // Per azienda: l'elenco sul dispositivo, le versioni dei rapporti e chi genera.
    private(set) var store: AdminCraftedArtifactStore?
    private(set) var reportVersions: AdminCraftedReportVersionStore?
    private(set) var generator: AdminCraftedGenerator?

    /// L'ultimo artifact eliminato, finché si può annullare.
    var lastRemoved: AdminCraftedArtifact?

    @ObservationIgnored var loadedKey: String?
    @ObservationIgnored var undoTask: Task<Void, Never>?
    /// I generatori di un'azienda lasciata mentre lavoravano: finiscono nel loro store.
    @ObservationIgnored var retiredGenerators: [AdminCraftedGenerator] = []
    /// I lettori aperti: stesso oggetto finché la schermata è nel percorso (non si rifanno a ogni disegno).
    @ObservationIgnored var artifactReaders: [String: AdminCraftedArtifactReaderViewModel] = [:]
    @ObservationIgnored var reportReaders: [String: AdminCraftedReportReaderViewModel] = [:]

    init(backend: AriaBackend) {
        self.backend = backend
        // Gli store (artifacts.json, report-versions.json) si aprono al primo load(), non all'avvio dell'app.
    }

    /// Cambia quando va richiesto tutto di nuovo: azienda o stabilimento.
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(backend.activePlantId ?? "-")" }

    // MARK: Azienda

    /// Gli store sono per azienda: cambiata l'azienda, se ne apre uno nuovo (e quello vecchio lascia finire i suoi turni).
    func syncCompany() {
        guard let companyId = backend.activeCompanyId else {
            dropStores()
            return
        }
        guard store?.companyId != companyId else { return }
        dropStores()
        let newStore = AdminCraftedArtifactStore(companyId: companyId)
        store = newStore
        reportVersions = AdminCraftedReportVersionStore(companyId: companyId)
        generator = AdminCraftedGenerator(backend: backend, store: newStore)
    }

    private func dropStores() {
        guard store != nil else { return }
        if let generator, !generator.isIdle { retiredGenerators.append(generator) }
        retiredGenerators.removeAll { $0.isIdle }
        store = nil
        reportVersions = nil
        generator = nil
        path = []
        composer = nil
        dismissUndo()
    }

    // MARK: Caricamento

    func load() async {
        syncCompany()
        let key = loadKey
        // Altra azienda o stabilimento: quello che c'era non vale, non si mostra mentre arriva il nuovo.
        if key != loadedKey {
            clearReviews()
            loadedKey = key
        }
        guard let companyId = backend.activeCompanyId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminCraftedAPI.sessionReviews(companyId: companyId,
                                                                                     plantId: backend.activePlantId))
            guard key == loadKey, !Task.isCancelled else { return }
            reviews = response.sessions?.items ?? []
            reviewsLoaded = true
            reviewsNote = nil
            lastUpdated = .now
        } catch {
            guard key == loadKey, !Task.isCancelled else { return }
            apply(loadError: error)
        }
    }

    /// Un 403 è un ruolo che non vede i rapporti (solo owner e admin): si dice com'è e si resta con gli artifact.
    private func apply(loadError error: any Error) {
        if case .http(let status, _)? = error as? AriaError, status == 403 {
            reviewsNote = .restricted
        } else if case .notOnPhone? = error as? AriaError {
            reviewsNote = .restricted
        } else if let message = AdminCraftedFailure.message(for: error, backend: backend) {
            reviewsNote = .failed(message)
        } else {
            return
        }
        // Un 403 non lascia i rapporti di prima: non sono di questo ruolo.
        if reviewsNote == .restricted {
            reviews = []
            reviewsLoaded = false
        }
    }

    private func clearReviews() {
        reviews = []
        reviewsLoaded = false
        reviewsNote = nil
        lastUpdated = nil
    }

    // MARK: Uscita

    /// All'uscita dall'account: non resta niente dell'azienda precedente, e niente continua a generare.
    func reset() {
        generator?.cancelAll()
        for old in retiredGenerators { old.cancelAll() }
        retiredGenerators = []
        undoTask?.cancel()
        undoTask = nil
        lastRemoved = nil
        store = nil
        reportVersions = nil
        generator = nil
        artifactReaders = [:]
        reportReaders = [:]
        path = []
        composer = nil
        clearReviews()
        loadedKey = nil
        isLoading = false
        searchText = ""
        category = nil
        sort = .recent
    }
}
