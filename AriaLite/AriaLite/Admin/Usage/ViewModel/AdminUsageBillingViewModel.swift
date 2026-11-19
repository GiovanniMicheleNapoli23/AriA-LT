//
//  AdminUsageBillingViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I controlli di fatturazione dei titolari (contratto 5): il limite di spesa, il suo storico, i destinatari degli avvisi e le
//  regole degli avvisi. Lo stato sta qui, le decisioni nelle estensioni per scheda (`+SpendCap`, `+History`, `+Recipients`,
//  `+Notices`) e i testi nei costruttori puri. Fonti condivise con la pagina (`AdminUsageViewModel`): config e saldo
//  (`backend.usage`), i fatti, i membri e i nomi. Le scritture e il salvataggio automatico li possiede questo view model, mai
//  la vista; una risposta partita prima di un cambio di azienda, di un'uscita o di un `reset()` non scrive.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminUsageBillingViewModel {
    let backend: AriaBackend
    let page: AdminUsageViewModel

    // MARK: Limite di spesa (5.1)

    /// GET /v1/usage/spend-cap; `nil` finché non si legge e dopo un errore a freddo.
    var cap: AriaSpendCapView?
    var capPhase: AdminUsagePhase = .idle
    /// "Change" è stato premuto: il campo si apre sul limite in vigore.
    var capEditing = false
    /// Quello che si è scritto nel campo; `nil` finché non si tocca.
    var capDraft: String?
    /// L'ultimo invio non era valido: "Enter an amount of {minimum} or more.".
    var capInvalid = false
    var capSaving = false
    var capSaveFailed = false
    /// "Lower the limit below what's already used?": in attesa della conferma.
    var capConfirmation: AdminUsageSpendCapConfirmation?
    /// "Spending limit saved" / "Spending limit removed", per qualche secondo.
    var toast: AdminUsageBillingToast?

    // MARK: Storico (5.2)

    var history: [AriaSpendCapChange] = []
    var historyPhase: AdminUsagePhase = .idle

    // MARK: Destinatari (5.3)

    /// La lista degli aggiunti come l'utente la vede finché il salvataggio non si chiude; `nil` = quella del server.
    var recipientDraft: [String]?
    /// Le persone che il server ha rifiutato (422), col nome che avevano allora.
    var recipientRefused: [AdminUsageRefusedPerson] = []
    let recipientsSaver = AdminUsageAutosave<[String]>()

    // MARK: Regole degli avvisi (5.4)

    /// La vista che si mostra: l'ultima risposta del server più le modifiche fatte dopo.
    var settings: AriaNoticeSettings?
    var settingsPhase: AdminUsagePhase = .idle
    /// Quello che si sta scrivendo nei campi delle soglie e le soglie non valide.
    var thresholdDrafts: [AriaNoticeKey: String] = [:]
    var thresholdErrors: [AriaNoticeKey: AdminUsageNoticeThresholdError] = [:]
    /// Le persone nominate che il server ha rifiutato (422).
    var inactiveIds: [String] = []
    /// L'ultimo rifiuto non si ripara con "Retry": serve prima correggere un valore (soglia fuori intervallo, persona inattiva).
    var settingsRefused = false
    let settingsSaver = AdminUsageAutosave<AdminUsageNoticeSave>()
    /// Il body con tutto quello che l'azienda tiene come suo, dopo l'ultima modifica accettata.
    @ObservationIgnored var intendedBody = AriaNoticeOverrides()
    /// Quello che il server tiene (ultima risposta): serve a non rimandare un body che non cambia niente.
    @ObservationIgnored var confirmedBody = AriaNoticeOverrides()
    /// Cresce a ogni modifica: una risposta vecchia non sostituisce la vista se ne sono arrivate di nuove.
    @ObservationIgnored var editVersion = 0

    // MARK: Interno

    /// Cresce a ogni `reset()`: le risposte partite prima non scrivono.
    @ObservationIgnored var epoch = 0
    @ObservationIgnored var capTask: Task<Void, Never>?
    @ObservationIgnored var toastTask: Task<Void, Never>?
    @ObservationIgnored var toastCounter = 0
    /// Quando si è letto per l'ultima volta: tornare sulla pagina non rilegge se è ancora fresco.
    @ObservationIgnored var loadedAt: Date?
    /// L'azienda a cui appartiene quello che si tiene (`page.loadKey`): se cambia, si butta tutto prima di rileggere.
    @ObservationIgnored var ownerKey: String?

    static let freshness: TimeInterval = 30

    init(backend: AriaBackend, page: AdminUsageViewModel) {
        self.backend = backend
        self.page = page
        recipientsSaver.send = { [weak self] ids in await self?.sendRecipients(ids) ?? false }
        settingsSaver.send = { [weak self] save in await self?.sendSettings(save) ?? false }
    }

    /// Cambia quando va riletto tutto: azienda diversa (per `.task(id:)`).
    var loadKey: String { page.loadKey }

    /// All'uscita dall'account: niente limiti, nomi né regole dell'azienda precedente.
    func reset() {
        epoch += 1
        capTask?.cancel()
        capTask = nil
        toastTask?.cancel()
        toastTask = nil
        cap = nil
        capPhase = .idle
        capEditing = false
        capDraft = nil
        capInvalid = false
        capSaving = false
        capSaveFailed = false
        capConfirmation = nil
        toast = nil
        history = []
        historyPhase = .idle
        recipientDraft = nil
        recipientRefused = []
        recipientsSaver.reset()
        settings = nil
        settingsPhase = .idle
        thresholdDrafts = [:]
        thresholdErrors = [:]
        inactiveIds = []
        settingsRefused = false
        settingsSaver.reset()
        intendedBody = AriaNoticeOverrides()
        confirmedBody = AriaNoticeOverrides()
        editVersion = 0
        loadedAt = nil
    }

    /// Un'altra azienda: limite, storico, regole e destinatari dell'altra non devono restare in vista né dare il corpo di una
    /// modifica (un PUT manderebbe le sostituzioni di A sull'azienda B).
    func claimCompany() {
        let key = loadKey
        if let ownerKey, ownerKey != key { reset() }
        ownerKey = key
    }

    // MARK: Chi vede cosa

    /// Si leggono e si mostrano i controlli: un titolare (`config.can_manage_plan`, mai `access.admin`) che i clienti
    /// possono vedere. Falso dopo un rifiuto da titolare.
    var isActive: Bool { page.isOwner && page.customersMaySee }

    /// Il limite e il suo storico ci sono solo con un piano assegnato.
    var showsLimit: Bool { page.hasPlan }

    // MARK: Letture

    /// All'apertura e al cambio di azienda: limite, storico e regole degli avvisi. I destinatari li legge la pagina (i membri).
    /// Con tutto già in mano e ancora fresco non rilegge: la vista torna a comparire spesso.
    func load() async {
        claimCompany()
        if let loadedAt, Date.now.timeIntervalSince(loadedAt) < Self.freshness, allRead { return }
        await refresh()
    }

    /// Tutto quello che serve è letto (anche una lettura andata a vuoto perché annullata si rifà).
    private var allRead: Bool {
        settingsPhase == .loaded && (!showsLimit || (capPhase == .loaded && historyPhase == .loaded))
    }

    /// Pull to refresh, ritorno in primo piano e dopo una scrittura: rilegge tutto senza tornare ai segnaposto.
    func refresh() async {
        claimCompany()
        guard isActive else { return }
        let stamp = currentStamp()
        async let limit: Void = loadLimit()
        async let rules: Void = loadSettings()
        _ = await (limit, rules)
        if isCurrent(stamp) { loadedAt = .now }
    }

    /// Il limite e il suo storico: solo con un piano assegnato (senza, le chiamate non si fanno).
    private func loadLimit() async {
        guard showsLimit else { return }
        async let spendCap: Void = loadSpendCap()
        async let spendHistory: Void = loadHistory()
        _ = await (spendCap, spendHistory)
    }
}

/// Una richiesta di PUT /v1/usage/notice-settings in coda: il body intero e la versione della vista da cui nasce.
nonisolated struct AdminUsageNoticeSave: Sendable, Equatable {
    var body: AriaNoticeOverrides
    var version: Int
}
