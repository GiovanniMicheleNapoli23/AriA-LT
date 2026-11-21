//
//  AdminUsageViewModel+Loading.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le letture della pagina Usage: config e saldo dallo store condiviso, cruscotto corrente e del ciclo scelto, membri
//  del titolare. Si legge all'apertura, al ritorno in primo piano, con il pull to refresh e dopo ogni scrittura della
//  fatturazione. Una risposta di un'altra azienda, di un altro ciclo o dopo un'uscita non scrive.
//

import Foundation

extension AdminUsageViewModel {
    // MARK: Apertura e rilettura

    /// All'apertura: la config (se serve), poi cruscotto, saldo e membri insieme.
    func load() async {
        claimCompany()
        // Ogni apertura è un tentativo nuovo: un altro `operation_forbidden` deve poter richiudere la sezione.
        sectionClosed = false
        let epoch = self.epoch
        let company = loadKey
        await backend.usage.loadConfig()
        await readEverything(epoch: epoch, company: company)
    }

    /// Entrando nella sezione: legge se non c'è niente in mano (prima volta, dopo un errore o una chiusura) o se il
    /// cruscotto ha più di 45 secondi; altrimenti mostra quello che c'è. Tirare per aggiornare, il primo piano e le
    /// scritture della fatturazione chiamano `refresh()`, che rilegge sempre.
    func loadIfNeeded() async {
        claimCompany()
        if currentDashboard == nil || sectionClosed || freshness.isStale() {
            await load()
        }
    }

    /// Pull to refresh, primo piano e dopo una scrittura: cruscotto, saldo e config (forzata).
    func refresh() async {
        claimCompany()
        let epoch = self.epoch
        let company = loadKey
        await backend.usage.loadConfig(force: true)
        await readEverything(epoch: epoch, company: company)
    }

    /// "Retry" della pagina non disponibile: la config se non c'è, poi il cruscotto (e il saldo).
    func retry() async {
        claimCompany()
        let epoch = self.epoch
        let company = loadKey
        await backend.usage.loadConfig(force: backend.usage.config == nil)
        await readEverything(epoch: epoch, company: company)
    }

    /// "Retry" della scheda dei contatori, dell'archivio, di Live Talk e del tetto: solo il saldo.
    func retryAllowance() async {
        await backend.usage.refreshAllowance()
    }

    /// "Retry" dei nomi.
    func retryMembers() async {
        await loadMembers()
    }

    private func readEverything(epoch: Int, company: String) async {
        guard isCurrent(epoch: epoch, company: company), customersMaySee else { return }
        async let dashboards: Void = readDashboards()
        async let allowance: Void = backend.usage.refreshAllowance()
        async let people: Void = loadMembers()
        _ = await (dashboards, allowance, people)
    }

    private func readDashboards() async {
        async let current: Void = loadCurrent()
        async let selected: Void = loadSelected()
        _ = await (current, selected)
    }

    // MARK: Cruscotti

    func loadCurrent() async {
        let epoch = self.epoch
        let company = loadKey
        // Con un cruscotto in mano la rilettura è silenziosa: la pagina non torna ai segnaposto.
        if currentDashboard == nil { currentPhase = .loading }
        do {
            let fresh = try await AriaUsageAPI(api: backend.api).dashboard()
            guard isCurrent(epoch: epoch, company: company) else { return }
            currentDashboard = fresh
            currentPhase = .loaded
            freshness.markLoaded()
            cycles = fresh.cycles
            if let start = fresh.period?.start, let end = fresh.period?.end {
                currentCycle = AriaUsageDashboard.Cycle(start: start, end: end)
            }
        } catch {
            guard isCurrent(epoch: epoch, company: company) else { return }
            if react(to: error) {
                // Mai cifre tenute dopo un errore: il selettore (`cycles`) resta, i numeri no.
                currentDashboard = nil
                currentPhase = .failed
            } else if currentDashboard == nil {
                currentPhase = .idle
            }
        }
    }

    func loadSelected() async {
        guard let requested = selectedCycle else { return }
        let epoch = self.epoch
        let company = loadKey
        do {
            let fresh = try await AriaUsageAPI(api: backend.api).dashboard(from: requested.start, to: requested.end)
            guard isCurrent(epoch: epoch, company: company), selectedCycle?.start == requested.start else { return }
            pastDashboard = fresh
            pastPhase = .loaded
        } catch {
            guard isCurrent(epoch: epoch, company: company), selectedCycle?.start == requested.start else { return }
            pastDashboard = nil
            pastPhase = react(to: error) ? .failed : .idle
        }
    }

    // MARK: Membri del titolare

    /// I membri attivi di `GET /v1/usage/notice-recipients`: solo un titolare. Un 403 nasconde le parti da titolare e fa
    /// rileggere la config.
    func loadMembers() async {
        guard backend.usage.config?.canManagePlan == true else { return }
        let epoch = self.epoch
        let company = loadKey
        if membersPhase != .loaded { membersPhase = .loading }
        do {
            let answer = try await AriaUsageAPI(api: backend.api).noticeRecipients()
            guard isCurrent(epoch: epoch, company: company) else { return }
            applyRecipients(answer)
        } catch {
            guard isCurrent(epoch: epoch, company: company) else { return }
            switch AdminUsageFailure.classify(error, ownerCall: true) {
            case .cancelled:
                membersPhase = members.isEmpty ? .idle : .loaded
            case .ownerRefused:
                ownerRefused = true
                membersPhase = .failed
                await backend.usage.loadConfig(force: true)
            default:
                membersPhase = react(to: error, ownerCall: true) ? .failed : .idle
            }
        }
    }

    /// Una risposta fresca dei destinatari (anche dopo un salvataggio dei controlli di fatturazione): i nomi si aggiornano.
    func applyRecipients(_ recipients: AriaNoticeRecipients) {
        members = recipients.members
        membersPhase = .loaded
        ownerRefused = false
    }

    // MARK: Errori

    /// Agisce sull'errore e dice se la lettura è da considerare fallita (`true`) o solo annullata (`false`).
    /// - sessione scaduta: `backend.handle`; sessione chiusa dal titolare: si lascia l'azienda;
    /// - `operation_forbidden`: la sezione si chiude (`sectionClosed`, per la shell).
    @discardableResult
    func react(to error: any Error, ownerCall: Bool = false) -> Bool {
        switch AdminUsageFailure.classify(error, ownerCall: ownerCall) {
        case .cancelled:
            return false
        case .signedOut:
            backend.handle(error)
        case .sessionEnded:
            Task { await backend.leaveEndedWorkspace() }
        case .sectionClosed:
            sectionClosed = true
        case .ownerRefused, .failed:
            break
        }
        return true
    }
}
