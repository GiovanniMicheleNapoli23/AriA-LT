//
//  AdminAlarmDiagnosisViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il pulsante "Diagnose" del dettaglio (POST /v1/agents/diagnostic): causa, gravità, passi, ricambi e
//  ordine di lavoro suggerito. Da lì si apre il modulo dell'ordine (POST /v1/work-orders), che l'utente
//  conferma.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAlarmDiagnosisViewModel {
    /// L'allarme da diagnosticare: il dettaglio lo aggiorna quando lo rilegge.
    var alarm: AdminAlarm
    private let backend: AriaBackend

    /// Contesto in più per l'agente (additional_context).
    var context = ""
    private(set) var isRunning = false
    private(set) var diagnosis: AdminAlarmDiagnosis?
    private(set) var failure: AdminAlarmAssistFailure?
    /// Il modulo dell'ordine di lavoro aperto (sheet).
    var workOrderForm: AdminAlarmWorkOrderFormViewModel?
    /// L'ordine creato da questa diagnosi.
    private(set) var createdWorkOrder: AdminAlarmCreatedWorkOrder?

    @ObservationIgnored private var task: Task<Void, Never>?

    init(alarm: AdminAlarm, backend: AriaBackend) {
        self.alarm = alarm
        self.backend = backend
    }

    // MARK: Diagnosi

    func diagnose() {
        guard !isRunning else { return }
        task?.cancel()
        task = Task { await run() }
    }

    private func run() async {
        isRunning = true
        failure = nil
        defer { isRunning = false }
        let extra = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = AdminAlarmDiagnosticRequest(alarmCode: alarm.code, assetTag: alarm.assetTag,
                                               additionalContext: extra.isEmpty ? nil : extra)
        do {
            let result = try await AdminAlarmsAPI(api: backend.api).diagnose(body)
            guard !Task.isCancelled else { return }
            diagnosis = result
            createdWorkOrder = nil
        } catch {
            guard let found = AdminAlarmAssistFailure.from(error, action: nil, backend: backend) else { return }
            failure = found
        }
    }

    /// Scarta il risultato (il dettaglio si chiude o l'utente vuole rifarla).
    func clear() {
        diagnosis = nil
        failure = nil
        createdWorkOrder = nil
    }

    /// Alla chiusura della schermata: la richiesta in corso non serve più.
    func cancel() {
        task?.cancel()
        task = nil
    }

    // MARK: Ordine di lavoro

    func startWorkOrder() {
        guard let diagnosis else { return }
        workOrderForm = AdminAlarmWorkOrderFormViewModel(
            alarm: alarm, diagnosis: diagnosis, backend: backend
        ) { [weak self] created in
            self?.createdWorkOrder = created
        }
    }
}
