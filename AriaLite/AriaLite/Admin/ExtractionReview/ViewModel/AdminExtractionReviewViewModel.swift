//
//  AdminExtractionReviewViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Extraction Review, come la pagina /extraction/review della web: asset, allarmi, piani e
//  ricambi che l'AI ha estratto dai documenti e aspettano una revisione (stato `draft` o `staged`).
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro. Le azioni sono in +Actions.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminExtractionReviewViewModel {
    let backend: AriaBackend

    /// I pending di ogni tipo, come arrivano dal server.
    var items: [AdminExtractionKind: [AdminExtractionItem]] = [:]
    /// Errore di caricamento di un tipo: gli altri tipi restano.
    private(set) var loadErrors: [AdminExtractionKind: String] = [:]
    private(set) var isLoading = false
    /// Le liste sono arrivate almeno una volta per l'azienda e lo stabilimento attivi.
    private(set) var hasLoaded = false
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?

    var kind: AdminExtractionKind = .assets {
        didSet { if kind != oldValue { endSelection() } }
    }
    var searchText = ""

    /// Modalità selezione multipla e gli id (`AdminExtractionItem.id`) scelti, del tipo a schermo.
    var isSelecting = false
    var selection: Set<String> = []
    /// Elementi con una richiesta in corso (approvazione, rifiuto).
    var busyIds: Set<String> = []
    var isBulkApproving = false
    /// Errore di un'azione: si mostra in un avviso.
    var actionError: String?

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    init(backend: AriaBackend) {
        self.backend = backend
    }

    var client: AdminExtractionReviewClient { AdminExtractionReviewClient(api: backend.api) }

    /// Cambia quando vanno richieste le liste: azienda o stabilimento (i ricambi si chiedono per stabilimento).
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(backend.activePlantId ?? "-")" }

    // MARK: Liste

    /// I pending di un tipo nello stabilimento attivo (quelli senza stabilimento valgono per tutti),
    /// prima i meno sicuri: sono quelli che chiedono più attenzione.
    func pendingItems(_ kind: AdminExtractionKind) -> [AdminExtractionItem] {
        let plant = backend.activePlantId
        return (items[kind] ?? [])
            .filter { plant == nil || $0.plantId == nil || $0.plantId == plant }
            .filter(\.isPending)
            .sorted { lhs, rhs in
                switch (lhs.confidence, rhs.confidence) {
                case let (l?, r?) where l != r: l < r
                case (_?, nil): true
                case (nil, _?): false
                default: lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
            }
    }

    func pendingCount(_ kind: AdminExtractionKind) -> Int { pendingItems(kind).count }

    var totalPending: Int { AdminExtractionKind.allCases.reduce(0) { $0 + pendingCount($1) } }

    var visibleItems: [AdminExtractionItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = pendingItems(kind)
        guard !query.isEmpty else { return rows }
        return rows.filter { $0.searchableFields.contains { $0.localizedStandardContains(query) } }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var loadError: String? { loadErrors[kind] }

    /// "Assets 4": l'etichetta di un segmento.
    func segmentTitle(_ kind: AdminExtractionKind) -> String {
        hasLoaded ? "\(kind.shortTitle) \(pendingCount(kind))" : kind.shortTitle
    }

    var subtitle: String {
        let count = visibleItems.count
        return String(localized: "\(count) to review")
    }

    func isBusy(_ item: AdminExtractionItem) -> Bool { busyIds.contains(item.id) }

    // MARK: Caricamento

    func load() async {
        let key = loadKey
        if key != loadedKey {
            // Altra azienda o altro stabilimento: le liste vecchie non valgono.
            items = [:]
            loadErrors = [:]
            hasLoaded = false
            endSelection()
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }

        let client = client
        let plantId = backend.activePlantId
        // Otto richieste insieme: quattro tipi per due stati (il filtro `status` ne accetta uno solo).
        let results = await withTaskGroup(of: (AdminExtractionKind, Result<[AdminExtractionItem], any Error>).self) { group in
            for kind in AdminExtractionKind.allCases {
                for status in AdminExtractionStatus.pending {
                    group.addTask {
                        do { return (kind, .success(try await client.items(kind, status: status, plantId: plantId))) }
                        catch { return (kind, .failure(error)) }
                    }
                }
            }
            var all: [(AdminExtractionKind, Result<[AdminExtractionItem], any Error>)] = []
            for await result in group { all.append(result) }
            return all
        }
        guard key == loadKey, !Task.isCancelled else { return }

        for kind in AdminExtractionKind.allCases {
            let kindResults = results.filter { $0.0 == kind }.map(\.1)
            let successes = kindResults.compactMap { try? $0.get() }
            guard !successes.isEmpty else {
                // Nessuna delle due richieste è arrivata: la lista vecchia resta, si dice perché.
                for case .failure(let error) in kindResults.prefix(1) {
                    loadErrors[kind] = AdminExtractionReviewFailure.message(for: error, backend: backend)
                }
                continue
            }
            items[kind] = Self.unique(successes.flatMap { $0 })
            loadErrors[kind] = nil
        }
        hasLoaded = true
        lastUpdated = .now
        selection.formIntersection(Set(visibleItems.map(\.id)))
    }

    /// Lo stesso elemento in due stati non si mostra due volte.
    private static func unique(_ rows: [AdminExtractionItem]) -> [AdminExtractionItem] {
        var seen: Set<String> = []
        return rows.filter { seen.insert($0.id).inserted }
    }

    // MARK: Dopo una modifica

    /// Un elemento salvato nel dettaglio: prende il posto di quello vecchio; se non è più pending esce.
    func apply(_ item: AdminExtractionItem) {
        var rows = items[item.kind] ?? []
        if let index = rows.firstIndex(where: { $0.id == item.id }) { rows[index] = item } else { rows.append(item) }
        items[item.kind] = rows
    }

    func remove(_ ids: Set<String>, kind: AdminExtractionKind) {
        items[kind]?.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        items = [:]
        loadErrors = [:]
        isLoading = false
        hasLoaded = false
        lastUpdated = nil
        loadedKey = nil
        kind = .assets
        searchText = ""
        isSelecting = false
        selection = []
        busyIds = []
        isBulkApproving = false
        actionError = nil
    }
}
