//
//  AdminAlarmsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Alarms, come la pagina /alarms della web. Vive in AppViewModel: i dati restano fra un
//  cambio di sezione e l'altro. Il server filtra solo per stato (GET /v1/alarms?status=): ogni stato ha il
//  suo elenco, scaricato la prima volta che lo si apre; la ricerca filtra sul telefono.
//  Selezione e approvazione in blocco stanno in AdminAlarmsViewModel+Approval.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAlarmsViewModel {
    let backend: AriaBackend

    /// Cosa mostrare al posto della lista.
    enum Placeholder: Equatable {
        case loading
        case failed(AdminAlarmsFailure)
        case empty(AdminAlarmStatus)
        case noResults(String)
    }

    // MARK: - State

    /// Gli elenchi già scaricati, per stato.
    var alarmsByStatus: [AdminAlarmStatus: [AdminAlarm]] = [:]
    /// L'azienda a cui appartengono gli elenchi scaricati.
    private var loadedCompanyId: String?
    private(set) var isLoading = false
    private(set) var failure: AdminAlarmsFailure?
    private(set) var lastUpdated: Date?

    var query = ""
    private(set) var statusFilter: AdminAlarmStatus = .approved

    // Selezione e approvazione in blocco (vedi +Approval).
    var isSelecting = false
    var selection: Set<String> = []
    var showsApproveConfirmation = false
    var isApproving = false
    var approveError: String?
    /// L'esito dell'ultima approvazione, per un avviso in cima all'elenco.
    var notice: String?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// All'uscita dall'account: niente dati dell'azienda precedente.
    func reset() {
        alarmsByStatus = [:]
        loadedCompanyId = nil
        isLoading = false
        failure = nil
        lastUpdated = nil
        query = ""
        statusFilter = .approved
        isSelecting = false
        selection = []
        showsApproveConfirmation = false
        isApproving = false
        approveError = nil
        notice = nil
    }

    // MARK: - Caricamento

    /// Cambia quando va (ri)caricato l'elenco: azienda o stato scelto.
    var loadKey: String { "\(backend.activeCompanyId ?? "-")|\(statusFilter.rawValue)" }

    /// L'elenco dello stato scelto è già scaricato, ed è dell'azienda attiva.
    var hasLoaded: Bool { loadedCompanyId == backend.activeCompanyId && alarmsByStatus[statusFilter] != nil }

    var alarms: [AdminAlarm] { loadedCompanyId == backend.activeCompanyId ? alarmsByStatus[statusFilter] ?? [] : [] }

    func loadIfNeeded() async {
        if !hasLoaded { await refresh() }
    }

    func refresh() async {
        let companyId = backend.activeCompanyId
        let status = statusFilter
        let api = AdminAlarmsAPI(api: backend.api)
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await api.list(status: status.rawValue)
            // Nel frattempo è cambiata l'azienda: questo elenco non è più quello giusto.
            guard companyId == backend.activeCompanyId else { return }
            if loadedCompanyId != companyId { alarmsByStatus = [:] }
            loadedCompanyId = companyId
            alarmsByStatus[status] = fresh
            failure = nil
            lastUpdated = .now
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    // MARK: - Filtri

    func selectStatus(_ status: AdminAlarmStatus) {
        guard status != statusFilter else { return }
        statusFilter = status
        failure = nil
        notice = nil
        // Le bozze si approvano; negli altri stati non c'è selezione.
        if !status.isPending { endSelecting() }
        selection = []
    }

    var visibleAlarms: [AdminAlarm] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = q.isEmpty ? alarms : alarms.filter { alarm in
            [alarm.code, alarm.description, alarm.assetTag, alarm.zone, alarm.category].contains {
                $0?.localizedStandardContains(q) == true
            }
        }
        return rows.sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
    }

    var placeholder: Placeholder? {
        if !hasLoaded {
            if let failure { return .failed(failure) }
            return .loading
        }
        if alarms.isEmpty { return .empty(statusFilter) }
        guard visibleAlarms.isEmpty else { return nil }
        return .noResults(query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Lista già a schermo ma l'ultimo aggiornamento è fallito.
    var refreshFailed: Bool { hasLoaded && failure != nil }

    // MARK: - Modifiche

    /// Un allarme modificato o riletto: si aggiorna dov'è, e passa nell'elenco del suo nuovo stato.
    func didSave(_ alarm: AdminAlarm) {
        for status in alarmsByStatus.keys {
            alarmsByStatus[status]?.removeAll { $0.id == alarm.id }
        }
        if let status = alarm.status, alarmsByStatus[status] != nil {
            alarmsByStatus[status]?.append(alarm)
        }
    }
}
