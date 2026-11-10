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

    // MARK: - Intestazione

    /// I fatti dell'intestazione, nella griglia; quelli vuoti non si mostrano.
    var facts: [AdminAlarmFact] {
        let all: [(String, String, String?, String)] = [
            ("asset", String(localized: "Asset"), alarm.assetTag, "gearshape.2"),
            ("zone", String(localized: "Zone"), alarm.zone, "mappin.and.ellipse"),
            ("category", String(localized: "Category"), alarm.category, "tag"),
            ("hmi", String(localized: "HMI page"), alarm.hmiPage, "display"),
        ]
        return all.compactMap { id, label, value, icon in
            value.map { AdminAlarmFact(id: id, label: label, value: $0, systemImage: icon) }
        }
    }

    /// Fiducia dell'estrazione (0…1) per il misuratore, se c'è.
    var confidenceFraction: Double? { alarm.confidencePercent.map { Double($0) / 100 } }

    /// "Edited 2 days ago · Created on 12 Oct 2026", le date che ci sono.
    var timestampLine: String? {
        var parts: [String] = []
        if let updated = alarm.updatedAt {
            parts.append(String(localized: "Edited \(updated.formatted(.relative(presentation: .named)))"))
        }
        if let created = alarm.createdAt {
            parts.append(String(localized: "Created on \(created.formatted(date: .abbreviated, time: .omitted))"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var canApprove: Bool {
        alarm.status?.isPending == true && !isApproving && backend.rights.can(.approve, in: .alarms)
    }

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
