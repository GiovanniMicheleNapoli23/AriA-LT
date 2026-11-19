//
//  AdminAlarmEventsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  L'inbox degli eventi di allarme (quello che l'impianto ha alzato), come l'hook use-alarm-inbox della web:
//  elenco per filtro (All/Unread/Read) dell'impianto attivo, conteggio dei non letti per il pulsante nella
//  lista Alarms, "segna come letto" (uno o tutti) con la riga aggiornata subito. Elenco e conteggio bastano
//  della sezione Alarms; segnare come letto vuole `acknowledge`. Lo possiede AdminAlarmsViewModel.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAlarmEventsViewModel {
    let backend: AriaBackend

    /// Cosa mostrare al posto delle righe.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminAlarmsFailure)
        case empty(AdminAlarmEventFilter)
    }

    // MARK: - State

    private(set) var filter: AdminAlarmEventFilter = .all
    private var events: [AdminAlarmEvent] = []
    /// Chiave (azienda, impianto, filtro) a cui appartengono `events`.
    private var loadedKey: String?
    private(set) var isLoading = false
    private(set) var failure: AdminAlarmsFailure?
    private(set) var unreadCount = 0
    var showsMarkAllConfirmation = false
    private(set) var isMarkingAll = false
    /// Errore di "segna come letto" (alert).
    var actionError: String?
    var isShowingActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: niente dati dell'azienda precedente.
    func reset() {
        filter = .all
        events = []
        loadedKey = nil
        isLoading = false
        failure = nil
        unreadCount = 0
        showsMarkAllConfirmation = false
        isMarkingAll = false
        actionError = nil
    }

    // MARK: - Caricamento

    private var plantId: String? { backend.activePlantId }

    /// Cambia quando va (ri)caricato l'elenco: azienda, impianto o filtro.
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(plantId ?? "-")|\(filter.rawValue)" }

    private var hasLoaded: Bool { loadedKey == loadKey }

    func loadIfNeeded() async {
        if !hasLoaded { await refresh() }
    }

    func refresh() async {
        let key = loadKey
        let filter = filter
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await AdminAlarmEventsAPI(api: backend.api).list(filter: filter, plantId: plantId)
            // Nel frattempo è cambiato filtro, impianto o azienda: questo elenco non è più quello giusto.
            guard key == loadKey else { return }
            events = fresh
            loadedKey = key
            failure = nil
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
        await refreshUnreadCount()
    }

    /// Il conteggio per il pulsante: se fallisce resta quello di prima.
    func refreshUnreadCount() async {
        let plantId = plantId
        do {
            let count = try await AdminAlarmEventsAPI(api: backend.api).unreadCount(plantId: plantId)
            guard plantId == self.plantId else { return }
            unreadCount = count
        } catch {
            _ = AdminAlarmsFailure.from(error, action: .read, backend: backend)
        }
    }

    // MARK: - Filtri

    func selectFilter(_ newFilter: AdminAlarmEventFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        failure = nil
    }

    /// Le righe del filtro scelto, le più recenti per prime.
    var visibleEvents: [AdminAlarmEvent] {
        guard hasLoaded else { return [] }
        return events.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var placeholder: Placeholder? {
        if !hasLoaded {
            if let failure { return .failed(failure) }
            return .loading
        }
        return events.isEmpty ? .empty(filter) : nil
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { hasLoaded && failure != nil }

    // MARK: - Segna come letto

    var canAcknowledge: Bool { backend.rights.can(.acknowledge, in: .alarms) }

    /// "Segna tutti" ha senso solo se c'è qualcosa da segnare.
    var canMarkAll: Bool { canAcknowledge && (unreadCount > 0 || events.contains { !$0.isRead }) }

    /// Segna un evento come letto: la riga cambia subito; se la chiamata fallisce si rilegge l'elenco.
    func markRead(_ event: AdminAlarmEvent) async {
        guard canAcknowledge, !event.isRead else { return }
        apply { $0.id == event.id }
        do {
            try await AdminAlarmEventsAPI(api: backend.api).markRead(id: event.id)
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend), !failure.isNotFound {
                actionError = failure.message
            }
            await refresh()
            return
        }
        await refreshUnreadCount()
    }

    /// Segna come letti tutti gli eventi dell'impianto (con conferma).
    func markAllRead() async {
        guard canMarkAll, !isMarkingAll else { return }
        isMarkingAll = true
        defer { isMarkingAll = false }
        do {
            try await AdminAlarmEventsAPI(api: backend.api).markAllRead(plantId: plantId)
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend) {
                actionError = failure.message
            }
            return
        }
        apply { _ in true }
        await refreshUnreadCount()
    }

    /// Le righe non lette che rispondono a `matches` passano a lette (con l'ora di adesso). Nel filtro "non
    /// letti" escono dall'elenco; il conteggio scende subito, poi si rilegge dal server.
    private func apply(_ matches: (AdminAlarmEvent) -> Bool) {
        let now = Date.now
        var changed = 0
        for index in events.indices where !events[index].isRead && matches(events[index]) {
            events[index].isRead = true
            events[index].readAt = now
            changed += 1
        }
        unreadCount = max(0, unreadCount - changed)
        if filter == .unread { events.removeAll { $0.isRead } }
    }
}
