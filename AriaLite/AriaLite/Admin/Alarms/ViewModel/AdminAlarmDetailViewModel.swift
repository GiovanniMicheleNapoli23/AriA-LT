//
//  AdminAlarmDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un allarme (pagina /alarms/{id} della web): scheda riletta dal server (by-id), cause e
//  passi, modifica in un foglio, decisioni di revisione in ogni stato (Approve, Unapprove, Reject, Back to draft;
//  con conferma quelle che tolgono l'allarme dal lavoro; quali dipende dal ruolo), eliminazione (con conferma),
//  "Improve with AI" e diagnosi. Approvare passa da bulk-approve (che sincronizza la conoscenza), le altre
//  decisioni sono un PATCH dello stato.
//

import Foundation
import Observation
import SwiftUI

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
    /// La decisione di revisione in corso e l'errore dell'ultima (si mostra nel riquadro di revisione).
    private(set) var reviewing: AdminReviewAction?
    private(set) var reviewError: String?
    /// La decisione che aspetta la conferma (Reject, Unapprove).
    var confirmingReview: AdminReviewAction?
    var isConfirmingReview: Bool {
        get { confirmingReview != nil }
        set { if !newValue { confirmingReview = nil } }
    }
    /// "Eliminare questo allarme?" (conferma).
    var showsDeleteConfirmation = false
    private(set) var isDeleting = false
    /// Errore dell'eliminazione (alert).
    var deleteError: String?
    var isShowingDeleteError: Bool {
        get { deleteError != nil }
        set { if !newValue { deleteError = nil } }
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

    /// Eliminare vuole quello che servirebbe a rifiutarlo (AriaRights.canDelete).
    var canDelete: Bool {
        reviewing == nil && !isDeleting && backend.rights.canDelete(stored: alarm.statusKey, in: .alarms)
    }

    // MARK: - Revisione

    /// Le decisioni possibili ora (restano mentre una è in corso, ferme): nessuna mentre l'eliminazione è in corso.
    var reviewActions: [AdminReviewAction] {
        guard !isDeleting else { return [] }
        return AdminReviewAction.available(from: alarm.statusKey, in: .alarms, rights: backend.rights)
    }

    /// La barra delle decisioni: almeno una decisione, o una in corso. Lo stato lo dice il badge dell'intestazione.
    var showsReview: Bool { !reviewActions.isEmpty || reviewing != nil }

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

    /// Reject e Unapprove chiedono conferma; le altre partono subito.
    func requestReview(_ action: AdminReviewAction) {
        if action.needsConfirmation {
            confirmingReview = action
        } else {
            Task { await review(action) }
        }
    }

    /// Prende la decisione: Approve passa da bulk-approve (con un solo id, che sincronizza anche la conoscenza)
    /// e rilegge l'allarme; le altre sono un PATCH dello stato.
    func review(_ action: AdminReviewAction) async {
        guard reviewing == nil, reviewActions.contains(action) else { return }
        reviewing = action
        reviewError = nil
        defer { reviewing = nil }
        do {
            if action == .approve {
                try await AdminAlarmsAPI(api: backend.api).approve(ids: [alarm.id])
            } else {
                didSave(try await AdminAlarmsAPI(api: backend.api).update(id: alarm.id, AdminAlarmUpdate(status: action.target)))
                return
            }
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend) {
                reviewError = failure.message
            }
            return
        }
        owner.invalidateApproved()
        await load()
    }

    /// `true` se eliminato: la schermata si chiude. Un 404 vuol dire che non c'era già più.
    func delete() async -> Bool {
        guard canDelete, !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await AdminAlarmsAPI(api: backend.api).delete(id: alarm.id)
        } catch {
            guard let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend) else { return false }
            guard failure.isNotFound else {
                deleteError = failure.message
                return false
            }
        }
        owner.didDelete(id: alarm.id)
        return true
    }

    /// Alla chiusura della schermata: le richieste in corso non servono più.
    func cancel() {
        diagnosis.cancel()
    }
}
