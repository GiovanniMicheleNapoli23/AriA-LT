//
//  AriaSessionStore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
//
//  Le conversazioni salvate sul backend, condivise tra la sidebar (Fissate / Recenti)
//  e la schermata Chat: carica a pagine da 60, rinomina, elimina, fissa.
//  La sidebar non rilegge a ogni apertura (`loadIfNeeded`): solo se l'elenco ha qualche decina di secondi, se è di
//  un'altra azienda o sito, o se la chat aperta non ha ancora il suo titolo. Tirare per aggiornare rilegge sempre.
//

import Foundation
import Observation

@Observable
final class AriaSessionStore {
    private(set) var sessions: [AriaSessionSummary] = [] {
        didSet { rebuildDerived() }
    }
    private(set) var isLoading = false
    private(set) var reachedEnd = false
    var error: String?
    /// Conversazioni fissate in cima alla sidebar (solo su questo device).
    private(set) var pinnedIDs: [String] {
        didSet {
            UserDefaults.standard.set(pinnedIDs, forKey: Self.pinnedKey)
            rebuildDerived()
        }
    }
    /// Senza i briefing automatici, che non sono conversazioni dell'operatore. Calcolati una volta a ogni cambio di
    /// `sessions` o dei fissati: la sidebar li legge più volte per ogni ridisegno.
    private(set) var visible: [AriaSessionSummary] = []
    private(set) var pinned: [AriaSessionSummary] = []
    private(set) var recents: [AriaSessionSummary] = []

    @ObservationIgnored private let backend: AriaBackend
    /// Quando e per quale azienda/sito si è letta l'ultima pagina iniziale con successo.
    @ObservationIgnored private var freshness = AriaFreshness()
    @ObservationIgnored private var loadedScope: String?

    static let pageSize = 60
    private static let pinnedKey = "aria.chat.pinned_sessions"

    init(backend: AriaBackend) {
        self.backend = backend
        pinnedIDs = UserDefaults.standard.stringArray(forKey: Self.pinnedKey) ?? []
        rebuildDerived()
    }

    private var api: AriaChatAPI { AriaChatAPI(api: backend.api) }

    /// Ricalcola `visible`, `pinned` e `recents`; assegna solo ciò che cambia, perché ogni assegnazione ridisegna chi legge.
    private func rebuildDerived() {
        let visible = sessions.filter { !$0.sessionId.hasPrefix("__briefing-") }
        let pinnedSet = Set(pinnedIDs)
        let byID = Dictionary(visible.map { ($0.sessionId, $0) }, uniquingKeysWith: { first, _ in first })
        let pinned = pinnedIDs.compactMap { byID[$0] }
        let recents = visible.filter { !pinnedSet.contains($0.sessionId) }
        if visible != self.visible { self.visible = visible }
        if pinned != self.pinned { self.pinned = pinned }
        if recents != self.recents { self.recents = recents }
    }

    func isPinned(_ session: AriaSessionSummary) -> Bool {
        pinnedIDs.contains(session.sessionId)
    }

    // MARK: - Azioni

    /// Entrando nella sidebar: rilegge solo se serve. `activeSessionId` è la chat aperta, se ha già dei messaggi:
    /// una conversazione appena iniziata (assente dall'elenco, o senza titolo) fa rileggere per prendere il suo titolo.
    func loadIfNeeded(activeSessionId: String? = nil) async {
        guard backend.isReady, !isLoading else { return }
        let reload = freshness.isStale() || loadedScope != scope || lacksTitle(activeSessionId)
        guard reload else { return }
        await load()
    }

    /// Azienda e sito dell'elenco: cambiando uno dei due le conversazioni mostrate non valgono più.
    private var scope: String { "\(backend.activeCompanyId ?? "-")|\(backend.activePlantId ?? "-")" }

    private func lacksTitle(_ sessionId: String?) -> Bool {
        guard let sessionId else { return false }
        guard let session = sessions.first(where: { $0.sessionId == sessionId }) else { return true }
        return session.title?.isEmpty != false
    }

    /// Rilegge sempre (tirare per aggiornare, una modifica salvata, la fine di un turno della chat).
    func load(more: Bool = false) async {
        guard backend.isReady, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let readScope = scope
        do {
            let offset = more ? sessions.count : 0
            let page = try await api.sessions(limit: Self.pageSize, offset: offset)
            var seen = Set((more ? sessions : []).map(\.sessionId))
            let fresh = page.filter { seen.insert($0.sessionId).inserted }
            // Solo se cambia: si rilegge a ogni apertura della sidebar, e una lista uguale riassegnata ridisegnerebbe
            // le recenti mentre la sidebar scorre dentro.
            let loaded = (more ? sessions : []) + fresh
            if loaded != sessions { sessions = loaded }
            let ended = page.count < Self.pageSize
            if ended != reachedEnd { reachedEnd = ended }
            if error != nil { error = nil }
            if !more {
                freshness.markLoaded()
                loadedScope = readScope
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func rename(_ session: AriaSessionSummary, to title: String) async {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        do {
            try await api.rename(sessionId: session.sessionId, title: title)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Elimina la conversazione; se era quella aperta, la chat riparte da zero.
    func delete(_ session: AriaSessionSummary, closing chat: AriaAgentChat) async {
        do {
            try await api.delete(sessionId: session.sessionId)
            sessions.removeAll { $0.sessionId == session.sessionId }
            pinnedIDs.removeAll { $0 == session.sessionId }
            AriaTaskProgressStore.shared.forget(sessionId: session.sessionId)
            if session.sessionId == chat.sessionId { chat.newConversation() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePin(_ session: AriaSessionSummary) {
        if let index = pinnedIDs.firstIndex(of: session.sessionId) {
            pinnedIDs.remove(at: index)
        } else {
            pinnedIDs.insert(session.sessionId, at: 0)
        }
    }

    /// Al logout: un altro operatore non vede le conversazioni di chi c'era prima.
    func reset() {
        sessions = []
        reachedEnd = false
        error = nil
        pinnedIDs = []
        freshness.invalidate()
        loadedScope = nil
    }
}
