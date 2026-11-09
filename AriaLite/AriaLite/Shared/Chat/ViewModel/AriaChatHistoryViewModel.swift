//
//  AriaChatHistoryViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica dello storico delle chat: ricerca per titolo, gruppi per data, cosa mostrare quando la
//  lista è vuota, caricamento a pagine, rinomina ed eliminazione.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaChatHistoryViewModel {
    let chat: AriaAgentChat
    let store: AriaSessionStore
    let backend: AriaBackend

    /// I gruppi della lista, dal più recente.
    enum Period: CaseIterable, Hashable {
        case today, yesterday, lastWeek, older
    }

    struct Group: Identifiable {
        let period: Period
        let sessions: [AriaSessionSummary]
        var id: Period { period }
    }

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case notConnected
        case loading
        case failed(String)
        case empty
        case noResults(String)
    }

    // MARK: - State

    var query = ""
    /// La conversazione di cui si sta cambiando il titolo (alert).
    var renaming: AriaSessionSummary?

    init(chat: AriaAgentChat, store: AriaSessionStore, backend: AriaBackend) {
        self.chat = chat
        self.store = store
        self.backend = backend
    }

    // MARK: - Derived

    /// Le conversazioni che corrispondono alla ricerca (per titolo, maiuscole e accenti non contano).
    var visible: [AriaSessionSummary] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.visible }
        return store.visible.filter { ($0.title ?? "").localizedCaseInsensitiveContains(q) }
    }

    var groups: [Group] { Self.groups(visible, now: .now) }

    /// Oggi, ieri, ultima settimana, più vecchie; senza data in fondo. I gruppi vuoti non si mostrano.
    static func groups(_ sessions: [AriaSessionSummary], now: Date, calendar: Calendar = .current) -> [Group] {
        var byPeriod: [Period: [AriaSessionSummary]] = [:]
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)
        for session in sessions {
            let period: Period
            if let date = session.lastActivity {
                if calendar.isDate(date, inSameDayAs: now) { period = .today }
                else if let yesterday, calendar.isDate(date, inSameDayAs: yesterday) { period = .yesterday }
                else if date > now.addingTimeInterval(-7 * 86_400) { period = .lastWeek }
                else { period = .older }
            } else {
                period = .older
            }
            byPeriod[period, default: []].append(session)
        }
        return Period.allCases.compactMap { period in
            byPeriod[period].map { Group(period: period, sessions: $0) }
        }
    }

    /// "Carica altre" solo senza ricerca, con qualcosa già in lista e altre pagine sul server.
    var canLoadMore: Bool { !store.reachedEnd && !store.sessions.isEmpty && query.isEmpty }

    var placeholder: Placeholder? {
        if !backend.isReady { return .notConnected }
        if store.isLoading && store.sessions.isEmpty { return .loading }
        if let error = store.error, store.sessions.isEmpty { return .failed(error) }
        if visible.isEmpty && !store.isLoading { return query.isEmpty ? .empty : .noResults(query) }
        return nil
    }

    var isLoading: Bool { store.isLoading }

    func isCurrent(_ session: AriaSessionSummary) -> Bool {
        session.sessionId == chat.sessionId
    }

    func isPinned(_ session: AriaSessionSummary) -> Bool {
        store.isPinned(session)
    }

    // MARK: - Actions

    func load() async {
        await store.load()
    }

    func loadMore() async {
        await store.load(more: true)
    }

    func rename(_ session: AriaSessionSummary) {
        renaming = session
    }

    func delete(_ session: AriaSessionSummary) async {
        await store.delete(session, closing: chat)
    }
}
