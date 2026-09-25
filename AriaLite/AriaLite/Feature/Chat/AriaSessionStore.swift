//
//  AriaSessionStore.swift
//  AriaLite
//
//  Le conversazioni salvate sul backend, condivise tra la sidebar (Fissate / Recenti)
//  e la schermata Chat: carica a pagine da 60, rinomina, elimina, fissa.
//

import Foundation
import Observation

@Observable
final class AriaSessionStore {
    private(set) var sessions: [AriaSessionSummary] = []
    private(set) var isLoading = false
    private(set) var reachedEnd = false
    var error: String?
    /// Conversazioni fissate in cima alla sidebar (solo su questo device).
    private(set) var pinnedIDs: [String] {
        didSet { UserDefaults.standard.set(pinnedIDs, forKey: Self.pinnedKey) }
    }

    @ObservationIgnored private let backend: AriaBackend

    static let pageSize = 60
    private static let pinnedKey = "aria.chat.pinned_sessions"

    init(backend: AriaBackend) {
        self.backend = backend
        pinnedIDs = UserDefaults.standard.stringArray(forKey: Self.pinnedKey) ?? []
    }

    private var api: AriaChatAPI { AriaChatAPI(api: backend.api) }

    /// Senza i briefing automatici, che non sono conversazioni dell'operatore.
    var visible: [AriaSessionSummary] {
        sessions.filter { !$0.sessionId.hasPrefix("__briefing-") }
    }

    var pinned: [AriaSessionSummary] {
        let byID = Dictionary(visible.map { ($0.sessionId, $0) }, uniquingKeysWith: { first, _ in first })
        return pinnedIDs.compactMap { byID[$0] }
    }

    var recents: [AriaSessionSummary] {
        visible.filter { !pinnedIDs.contains($0.sessionId) }
    }

    func isPinned(_ session: AriaSessionSummary) -> Bool {
        pinnedIDs.contains(session.sessionId)
    }

    // MARK: - Azioni

    func load(more: Bool = false) async {
        guard backend.isReady, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let offset = more ? sessions.count : 0
            let page = try await api.sessions(limit: Self.pageSize, offset: offset)
            var seen = Set((more ? sessions : []).map(\.sessionId))
            let fresh = page.filter { seen.insert($0.sessionId).inserted }
            sessions = (more ? sessions : []) + fresh
            reachedEnd = page.count < Self.pageSize
            error = nil
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
    }
}
