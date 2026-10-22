//
//  AdminCraftedViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Crafted, come la pagina /crafted della web: i widget salvati dalle card di Aria (galleria,
//  filtro per tipo, ricerca, eliminazione) e le sessioni concluse (vedi +Sessions).
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedViewModel {
    let backend: AriaBackend

    var tab: AdminCraftedTab = .widgets
    var searchText = ""
    /// Il tipo di card scelto nel filtro (`kind`); nil = tutti.
    var kindFilter: String?
    /// Il verdetto scelto nel filtro delle sessioni; nil = tutti.
    var verdictFilter: String?

    private(set) var widgets: [AdminCraftedWidget] = []
    private(set) var widgetsLoaded = false
    private(set) var widgetsError: String?

    private(set) var sessions: [AdminCraftedSessionReview] = []
    private(set) var summary: AdminCraftedSessionSummary?
    private(set) var learned: [AdminCraftedLearned] = []
    private(set) var steps: [AdminCraftedSessionStep] = []
    private(set) var sessionsLoaded = false
    private(set) var sessionsError: String?

    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?

    // Eliminazione con conferma.
    var widgetToDelete: AdminCraftedWidget?
    var showsDeleteConfirmation = false
    private(set) var deletingId: String?
    var actionError: String?
    var showsActionError = false

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Cambia quando va richiesto tutto di nuovo: azienda o stabilimento.
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(backend.activePlantId ?? "-")" }

    // MARK: Widget

    /// I tipi dei widget scaricati, per il filtro.
    var kinds: [String] {
        Set(widgets.map(\.kind)).sorted { AdminCraftedKind.label($0).localizedStandardCompare(AdminCraftedKind.label($1)) == .orderedAscending }
    }

    var kindFilterLabel: String { kindFilter.map(AdminCraftedKind.label) ?? String(localized: "All types") }

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isSearching: Bool { !query.isEmpty }

    /// Nell'ordine scelto sulla web (`position`), poi per titolo.
    var visibleWidgets: [AdminCraftedWidget] {
        widgets
            .filter { kindFilter == nil || $0.kind == kindFilter }
            .filter { query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(query) } }
            .sorted {
                ($0.position ?? .max, $0.displayTitle.lowercased()) < ($1.position ?? .max, $1.displayTitle.lowercased())
            }
    }

    var widgetsSubtitle: String {
        let count = visibleWidgets.count
        return String(localized: "\(count) widgets")
    }

    func canDelete(_ widget: AdminCraftedWidget) -> Bool { widget.serverId != nil && deletingId == nil }

    func askDelete(_ widget: AdminCraftedWidget) {
        guard canDelete(widget) else { return }
        widgetToDelete = widget
        showsDeleteConfirmation = true
    }

    /// Elimina sul server e poi dalla lista: se il server dice di no il widget resta e l'errore va nell'alert.
    func delete(_ widget: AdminCraftedWidget) async {
        guard let message = await deleteReturningError(widget) else { return }
        actionError = message
        showsActionError = true
    }

    /// Come `delete`, ma l'errore torna a chi chiama (il dettaglio lo mostra sul posto): nil = eliminato
    /// o richiesta annullata.
    func deleteReturningError(_ widget: AdminCraftedWidget) async -> String? {
        guard let id = widget.serverId else { return nil }
        deletingId = id
        defer { deletingId = nil; widgetToDelete = nil }
        do {
            _ = try await backend.api.call(AdminCraftedAPI.deleteWidget(id: id))
            widgets.removeAll { $0.serverId == id }
            if let kind = kindFilter, !kinds.contains(kind) { kindFilter = nil }
            return nil
        } catch {
            return AdminCraftedFailure.message(for: error, backend: backend)
        }
    }

    /// Un widget appena fissato da una sessione: entra in galleria senza ricaricare.
    func added(_ widget: AdminCraftedWidget) {
        widgets.removeAll { $0.id == widget.id }
        widgets.append(widget)
    }

    /// Il prossimo `position`: in coda agli altri.
    var nextPosition: Int { (widgets.compactMap(\.position).max() ?? -1) + 1 }

    // MARK: Caricamento

    func load() async {
        let key = loadKey
        // Altra azienda o stabilimento: quello che c'era non vale, non si mostra mentre arriva il nuovo.
        if key != loadedKey {
            clearData()
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        async let widgetsDone: Void = loadWidgets(key: key)
        async let sessionsDone: Void = loadSessions(key: key)
        _ = await (widgetsDone, sessionsDone)
        if key == loadKey, widgetsLoaded || sessionsLoaded { lastUpdated = .now }
    }

    private func loadWidgets(key: String) async {
        do {
            let response = try await backend.api.call(AdminCraftedAPI.widgets())
            guard key == loadKey, !Task.isCancelled else { return }
            widgets = response.items
            widgetsLoaded = true
            widgetsError = nil
            if let kind = kindFilter, !kinds.contains(kind) { kindFilter = nil }
        } catch {
            guard key == loadKey, let message = AdminCraftedFailure.message(for: error, backend: backend) else { return }
            widgetsError = message
        }
    }

    private func loadSessions(key: String) async {
        guard let companyId = backend.activeCompanyId else {
            sessionsError = String(localized: "Choose a company to see its sessions.")
            return
        }
        do {
            let response = try await backend.api.call(AdminCraftedAPI.sessionReviews(companyId: companyId,
                                                                                     plantId: backend.activePlantId))
            guard key == loadKey, !Task.isCancelled else { return }
            sessions = response.sessions?.items ?? []
            summary = response.summary
            learned = response.learned?.items ?? []
            steps = response.steps?.items ?? []
            sessionsLoaded = true
            sessionsError = nil
            if let verdict = verdictFilter, !verdicts.contains(verdict) { verdictFilter = nil }
        } catch {
            guard key == loadKey, let message = AdminCraftedFailure.message(for: error, backend: backend) else { return }
            sessionsError = message
        }
    }

    /// Una sessione rinominata nel dettaglio: il titolo cambia anche in lista.
    func renamed(sessionId: String, title: String) {
        sessions = sessions.map { $0.sessionId == sessionId ? $0.withTitle(title) : $0 }
    }

    // MARK: Dettagli

    func makeWidgetDetail(for widget: AdminCraftedWidget) -> AdminCraftedWidgetDetailViewModel {
        AdminCraftedWidgetDetailViewModel(backend: backend, widget: widget)
    }

    func makeSessionDetail(for review: AdminCraftedSessionReview) -> AdminCraftedSessionViewModel {
        AdminCraftedSessionViewModel(
            backend: backend, review: review,
            learned: learned.filter { $0.sessionId == review.sessionId },
            steps: steps.filter { $0.sessionId == review.sessionId && ($0.episode ?? 1) == (review.episode ?? 1) },
            nextPosition: { [weak self] in self?.nextPosition ?? 0 },
            onPinned: { [weak self] in self?.added($0) },
            onRenamed: { [weak self] in self?.renamed(sessionId: review.sessionId, title: $0) })
    }

    // MARK: Uscita

    private func clearData() {
        widgets = []
        widgetsLoaded = false
        widgetsError = nil
        sessions = []
        summary = nil
        learned = []
        steps = []
        sessionsLoaded = false
        sessionsError = nil
        lastUpdated = nil
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        clearData()
        loadedKey = nil
        isLoading = false
        tab = .widgets
        searchText = ""
        kindFilter = nil
        verdictFilter = nil
        widgetToDelete = nil
        showsDeleteConfirmation = false
        deletingId = nil
        actionError = nil
        showsActionError = false
    }
}
