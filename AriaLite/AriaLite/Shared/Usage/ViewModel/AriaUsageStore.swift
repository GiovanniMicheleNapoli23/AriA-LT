//
//  AriaUsageStore.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Config dei crediti, saldo e stime di costo dell'azienda attiva, condivisi da chat, composer e profilo.
//  Ogni cifra viene dal server e non si calcola qui; un errore resta locale (niente numeri, si può riprovare)
//  e non tocca mai l'errore della chat né la sessione.
//

import Foundation
import Observation

@Observable
final class AriaUsageStore {
    enum Phase: Equatable { case idle, loading, loaded, failed }

    /// Quanto restano valide config e stime (come la web).
    static let freshness: TimeInterval = 60

    // MARK: Stato letto dalle viste

    /// Lo stato vero sta in `stored…`: se l'azienda (o l'account) cambia, le viste vedono subito niente
    /// invece delle cifre di prima, anche prima che qualcuno chieda di rileggere.
    private var storedConfig: AriaUsageConfig?
    private var storedConfigPhase: Phase = .idle
    private var storedAllowance: AriaAllowance?
    private var storedAllowancePhase: Phase = .idle
    private var storedUnavailable = false

    /// Ogni lettore legge prima lo stato memorizzato e poi `isCurrent`: così la vista si iscrive sempre agli
    /// aggiornamenti, anche quando legge prima del primo caricamento (niente `&&` che salta la lettura).
    var config: AriaUsageConfig? {
        let value = storedConfig
        return isCurrent ? value : nil
    }
    var configPhase: Phase {
        let value = storedConfigPhase
        return isCurrent ? value : .idle
    }
    var allowance: AriaAllowance? {
        let value = storedAllowance
        return isCurrent ? value : nil
    }
    var allowancePhase: Phase {
        let value = storedAllowancePhase
        return isCurrent ? value : .idle
    }
    /// Il backend non ha le rotte per questa sessione (403 `operation_forbidden`): si nasconde tutto.
    var isUnavailable: Bool {
        let value = storedUnavailable
        return isCurrent && value
    }

    // MARK: Interno

    @ObservationIgnored private weak var backend: AriaBackend?
    /// Azienda e account a cui appartiene quello che si tiene. Osservata: se cambia, le viste si rileggono.
    private var cacheKey: String?
    /// Cresce a ogni cambio di azienda: una risposta partita prima non scrive più.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var configLoadedAt: Date?
    @ObservationIgnored private var configTask: Task<Void, Never>?
    @ObservationIgnored private var allowanceTask: Task<Void, Never>?
    /// Un altro giro è stato chiesto mentre il saldo si stava già leggendo: la risposta in volo può essere vecchia.
    @ObservationIgnored private var allowanceIsDirty = false
    @ObservationIgnored private var estimates: [AriaEffortLevel: (estimate: AriaUsageEstimate, at: Date)] = [:]
    @ObservationIgnored private var estimateTasks: [AriaEffortLevel: Task<AriaUsageEstimate?, Never>] = [:]

    init(backend: AriaBackend) {
        self.backend = backend
    }

    private var currentKey: String {
        guard let backend, backend.isSignedIn else { return "" }
        return "\(backend.activeCompanyId ?? "")|\(backend.mobileAccount?.id ?? "")"
    }

    private var isCurrent: Bool {
        let key = currentKey
        return cacheKey != nil && cacheKey == key
    }

    /// Da scollegati, o senza azienda, non c'è niente da leggere.
    private func readyBackend() -> AriaBackend? {
        guard let backend, backend.isSignedIn, backend.activeCompanyId != nil else { return nil }
        let key = currentKey
        if key != cacheKey { drop(for: key) }
        return storedUnavailable ? nil : backend
    }

    /// L'azienda (o l'account) attiva è cambiata: si butta quello che si teneva e si rileggono config e saldo senza
    /// aspettare una vista (contratto 3.6). Lo chiama `AriaBackend` quando sceglie l'azienda.
    func companyChanged() {
        guard readyBackend() != nil else { return }
        Task { [weak self] in await self?.loadConfig() }
        Task { [weak self] in await self?.refreshAllowance() }
    }

    /// Un'altra azienda (o un altro account): config, saldo e stime dell'altra non valgono più.
    private func drop(for key: String) {
        cacheKey = key
        generation += 1
        configTask?.cancel()
        allowanceTask?.cancel()
        estimateTasks.values.forEach { $0.cancel() }
        configTask = nil
        allowanceTask = nil
        estimateTasks = [:]
        estimates = [:]
        allowanceIsDirty = false
        configLoadedAt = nil
        storedConfig = nil
        storedConfigPhase = .idle
        storedAllowance = nil
        storedAllowancePhase = .idle
        storedUnavailable = false
    }

    private func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    /// Il backend non ha la funzione (`notOnPhone`, o 404 sulla rotta di config e saldo): si nasconde tutto, senza una
    /// scheda d'errore per tutti. Per la stima un 404 resta un semplice "niente stima".
    private func noteRefusal(_ error: any Error, includingNotFound: Bool = false) {
        switch error as? AriaError {
        case .notOnPhone?: storedUnavailable = true
        case .http(let status, _)? where includingNotFound && status == 404: storedUnavailable = true
        default: break
        }
    }

    /// Il server o il ruolo sono cambiati (vedi `AriaBackend`): le funzioni nascoste si riprovano.
    func resetAvailability() {
        guard storedUnavailable else { return }
        storedUnavailable = false
        storedConfigPhase = .idle
        storedAllowancePhase = .idle
        companyChanged()
    }

    // MARK: Config

    /// Rilegge la config se è più vecchia di 60 s (o con `force`). Più viste insieme fanno una richiesta sola.
    func loadConfig(force: Bool = false) async {
        guard let backend = readyBackend() else { return }
        if let task = configTask {
            await task.value
            return
        }
        if !force, storedConfigPhase == .loaded, let at = configLoadedAt,
           Date.now.timeIntervalSince(at) < Self.freshness { return }
        let api = AriaUsageAPI(api: backend.api)
        let generation = self.generation
        // La chiave si prende ora: se l'azienda cambia mentre la richiesta è in volo, la risposta non vale.
        let key = currentKey
        // Con una config già in mano la rilettura è silenziosa: il menù non torna a "caricamento".
        if storedConfig == nil { storedConfigPhase = .loading }
        let task = Task { [weak self] in
            let result: Result<AriaUsageConfig, any Error>
            do { result = .success(try await api.config()) } catch { result = .failure(error) }
            self?.finishConfig(result, generation: generation, key: key)
        }
        configTask = task
        await task.value
    }

    private func finishConfig(_ result: Result<AriaUsageConfig, any Error>, generation: Int, key: String) {
        guard generation == self.generation else { return }
        configTask = nil
        guard key == currentKey else { return }
        switch result {
        case .success(let config):
            storedConfig = config
            storedConfigPhase = .loaded
            configLoadedAt = .now
        case .failure(let error) where isCancellation(error):
            // Interrotta: senza config si offre "riprova" invece di restare in "caricamento" per sempre.
            storedConfigPhase = storedConfig == nil ? .failed : .loaded
        case .failure(let error):
            noteRefusal(error, includingNotFound: true)
            // Mai una cifra tenuta dopo un errore: niente numeri, si riprova.
            storedConfig = nil
            storedConfigPhase = .failed
            configLoadedAt = nil
        }
    }

    // MARK: Saldo

    /// Rilegge il saldo. Più viste insieme fanno una richiesta sola.
    func refreshAllowance() async {
        await loadAllowance(afterEvent: false)
    }

    /// Dopo una risposta, un documento caricato o cancellato: il saldo è cambiato, si rilegge senza aspettare.
    func refreshAllowanceLater() {
        Task { [weak self] in await self?.loadAllowance(afterEvent: true) }
    }

    /// Dopo ogni risposta, comunque sia finita (anche Stop, 402, conversazione cambiata).
    func replyEnded() {
        refreshAllowanceLater()
    }

    private func loadAllowance(afterEvent: Bool) async {
        guard let backend = readyBackend() else { return }
        if let task = allowanceTask {
            // La risposta in volo è partita prima dell'evento: può non contarlo, si rilegge appena finisce.
            if afterEvent { allowanceIsDirty = true }
            await task.value
            return
        }
        let task = startAllowance(api: AriaUsageAPI(api: backend.api))
        await task.value
    }

    private func startAllowance(api: AriaUsageAPI) -> Task<Void, Never> {
        let generation = self.generation
        let key = currentKey
        // Con un saldo già in mano la rilettura è silenziosa: niente caricamento che lampeggia.
        // Ma dopo un errore resta `.failed` finché non arriva una risposta: la scheda non lampeggia a ogni giro da 60 s.
        if storedAllowance == nil, storedAllowancePhase != .failed { storedAllowancePhase = .loading }
        let task = Task { [weak self] in
            let result: Result<AriaAllowance, any Error>
            do { result = .success(try await api.allowance()) } catch { result = .failure(error) }
            self?.finishAllowance(result, generation: generation, key: key)
        }
        allowanceTask = task
        return task
    }

    private func finishAllowance(_ result: Result<AriaAllowance, any Error>, generation: Int, key: String) {
        guard generation == self.generation else { return }
        allowanceTask = nil
        guard key == currentKey else { return }
        switch result {
        case .success(let allowance):
            storedAllowance = allowance
            storedAllowancePhase = .loaded
        case .failure(let error) where isCancellation(error):
            storedAllowancePhase = storedAllowance == nil ? .failed : .loaded
        case .failure(let error):
            noteRefusal(error, includingNotFound: true)
            storedAllowance = nil
            storedAllowancePhase = .failed
        }
        if allowanceIsDirty {
            allowanceIsDirty = false
            if let backend = readyBackend() { _ = startAllowance(api: AriaUsageAPI(api: backend.api)) }
        }
    }

    // MARK: Stime

    /// Quanto costerebbe una risposta a questo livello (gratis). Cache di 60 s per azienda e livello;
    /// un errore (o una stima non leggibile) vale "niente stima", mai una cifra inventata.
    func estimate(_ level: AriaEffortLevel) async -> AriaUsageEstimate? {
        guard let backend = readyBackend() else { return nil }
        if let hit = estimates[level], Date.now.timeIntervalSince(hit.at) < Self.freshness { return hit.estimate }
        if let task = estimateTasks[level] { return await task.value }
        let api = AriaUsageAPI(api: backend.api)
        let generation = self.generation
        let key = currentKey
        let task = Task<AriaUsageEstimate?, Never> { [weak self] in
            do {
                let estimate = try await api.estimate(level)
                return self?.finishEstimate(.success(estimate), level: level, generation: generation, key: key)
            } catch {
                return self?.finishEstimate(.failure(error), level: level, generation: generation, key: key)
            }
        }
        estimateTasks[level] = task
        return await task.value
    }

    private func finishEstimate(_ result: Result<AriaUsageEstimate, any Error>, level: AriaEffortLevel,
                                generation: Int, key: String) -> AriaUsageEstimate? {
        guard generation == self.generation else { return nil }
        estimateTasks[level] = nil
        guard key == currentKey else { return nil }
        switch result {
        case .success(let estimate):
            estimates[level] = (estimate, .now)
            return estimate
        case .failure(let error):
            if !isCancellation(error) { noteRefusal(error) }
            return nil
        }
    }
}
