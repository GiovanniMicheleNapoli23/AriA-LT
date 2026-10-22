//
//  AdminAlarmDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un allarme (pagina /alarms/{id} della web): scheda riletta dal server (by-id), cause e
//  passi, modifica in un foglio, approvazione (con conferma), "Improve with AI" e diagnosi.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAlarmDetailViewModel {
    let owner: AdminAlarmsViewModel
    private var backend: AriaBackend { owner.backend }

    // MARK: - State

    private(set) var alarm: AdminAlarm {
        didSet { diagnosis.alarm = alarm }
    }
    private(set) var isLoading = false
    private(set) var failure: AdminAlarmsFailure?
    /// La diagnosi dell'allarme: ha il suo view model, il dettaglio lo tiene.
    let diagnosis: AdminAlarmDiagnosisViewModel
    /// Il modulo di modifica aperto (sheet).
    var editForm: AdminAlarmFormViewModel?
    /// "Improve with AI" aperto (sheet).
    var improve: AdminAlarmImproveViewModel?
    /// "Approvare questo allarme?" (conferma).
    var showsApproveConfirmation = false
    private(set) var isApproving = false
    /// Errore dell'approvazione (alert).
    var approveError: String?
    var isShowingApproveError: Bool {
        get { approveError != nil }
        set { if !newValue { approveError = nil } }
    }

    init(alarm: AdminAlarm, owner: AdminAlarmsViewModel) {
        self.alarm = alarm
        self.owner = owner
        diagnosis = AdminAlarmDiagnosisViewModel(alarm: alarm, backend: owner.backend)
    }

    // MARK: - Caricamento

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await AdminAlarmsAPI(api: backend.api).alarm(id: alarm.id)
            alarm = fresh
            owner.didSave(fresh)
            failure = nil
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    // MARK: - Scheda

    /// Le righe etichetta-valore della scheda; quelle vuote non si mostrano.
    var infoRows: [(label: String, value: String)] {
        var rows: [(String, String?)] = [
            (String(localized: "Asset"), alarm.assetTag),
            (String(localized: "Category"), alarm.category),
            (String(localized: "Zone"), alarm.zone),
            (String(localized: "HMI page"), alarm.hmiPage),
            (String(localized: "Extraction confidence"), alarm.confidencePercent.map { "\($0)%" }),
        ]
        rows.append((String(localized: "Created"), alarm.createdAt?.formatted(date: .abbreviated, time: .shortened)))
        rows.append((String(localized: "Updated"), alarm.updatedAt?.formatted(date: .abbreviated, time: .shortened)))
        return rows.compactMap { label, value in value.map { (label, $0) } }
    }

    var canApprove: Bool { alarm.status?.isPending == true && !isApproving }

    // MARK: - Azioni

    func startEditing() {
        editForm = AdminAlarmFormViewModel(alarm: alarm, backend: backend) { [weak self] saved in
            self?.didSave(saved)
        }
    }

    func startImproving() {
        improve = AdminAlarmImproveViewModel(alarm: alarm, backend: backend) { [weak self] saved in
            self?.didSave(saved)
        }
    }

    private func didSave(_ saved: AdminAlarm) {
        alarm = saved
        owner.didSave(saved)
    }

    /// Approva questo allarme (bulk-approve con un solo id, che sincronizza anche la conoscenza) e lo rilegge.
    func approve() async {
        guard canApprove else { return }
        isApproving = true
        defer { isApproving = false }
        do {
            try await AdminAlarmsAPI(api: backend.api).approve(ids: [alarm.id])
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend) {
                approveError = failure.message
            }
            return
        }
        owner.invalidateApproved()
        await load()
    }

    /// Alla chiusura della schermata: le richieste in corso non servono più.
    func cancel() {
        diagnosis.cancel()
    }
}
