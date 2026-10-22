//
//  AdminReasoningConsoleViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Reasoning console, come la pagina /settings/sessions della web: le sessioni con l'agente
//  dell'utente (GET /v1/agent/sessions è per utente, non per azienda), a pagine, con ricerca locale.
//  Vive in AppViewModel: i dati restano fra un cambio di sezione e l'altro.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminReasoningConsoleViewModel {
    let backend: AriaBackend
    let editor: AdminReasoningSessionEditor

    static let pageSize = 50

    private(set) var sessions: [AriaSessionSummary] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    /// L'ultima pagina era piena: sul server potrebbero essercene altre.
    private(set) var canLoadMore = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?

    var searchText = ""

    init(backend: AriaBackend) {
        self.backend = backend
        editor = AdminReasoningSessionEditor(backend: backend)
        editor.onRenamed = { [weak self] in self?.apply($0) }
        editor.onDeleted = { [weak self] in self?.remove(sessionId: $0) }
    }

    /// Cambia con l'azienda (e quindi con l'account): la vista ci appende un `.task`.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    private var api: AriaChatAPI { AriaChatAPI(api: backend.api) }

    // MARK: Lista

    /// Senza i briefing automatici (`__briefing-*`), le più recenti per prime, filtrate dalla ricerca.
    var visibleSessions: [AriaSessionSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sessions
            .filter { !$0.sessionId.hasPrefix("__briefing-") }
            .filter { query.isEmpty || ($0.title ?? "").localizedStandardContains(query) || $0.sessionId.localizedStandardContains(query) }
            .sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var subtitle: String {
        let count = visibleSessions.count
        return String(localized: "\(count) sessions")
    }

    // MARK: Caricamento

    func load() async {
        let key = loadKey
        if key != loadedKey {
            sessions = []
            hasLoaded = false
            errorMessage = nil
            canLoadMore = false
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await api.sessions(limit: Self.pageSize, offset: 0)
            guard key == loadKey, !Task.isCancelled else { return }
            sessions = page
            canLoadMore = page.count == Self.pageSize
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
        } catch {
            guard key == loadKey, let message = AdminReasoningConsoleFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    /// La pagina dopo: si chiede finché ne torna una corta.
    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        let key = loadKey
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await api.sessions(limit: Self.pageSize, offset: sessions.count)
            guard key == loadKey else { return }
            let known = Set(sessions.map(\.sessionId))
            sessions += page.filter { !known.contains($0.sessionId) }
            canLoadMore = page.count == Self.pageSize
        } catch {
            guard key == loadKey, let message = AdminReasoningConsoleFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    // MARK: Dopo una modifica

    func apply(_ session: AriaSessionSummary) {
        guard let index = sessions.firstIndex(where: { $0.sessionId == session.sessionId }) else { return }
        sessions[index] = session
    }

    func remove(sessionId: String) {
        sessions.removeAll { $0.sessionId == sessionId }
    }

    func makeSessionViewModel(for session: AriaSessionSummary) -> AdminReasoningSessionViewModel {
        let child = AdminReasoningSessionViewModel(backend: backend, session: session)
        child.onRenamed = { [weak self] in self?.apply($0) }
        child.onDeleted = { [weak self] in self?.remove(sessionId: $0) }
        return child
    }

    func makeTurnViewModel(for turn: AdminReasoningTurnSummary) -> AdminReasoningTurnViewModel {
        AdminReasoningTurnViewModel(backend: backend, summary: turn)
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        sessions = []
        isLoading = false
        isLoadingMore = false
        canLoadMore = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        loadedKey = nil
        searchText = ""
        editor.reset()
    }
}
