//
//  AriaEffortPickerViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La logica del foglio "Effort": quale schermata mostrare (attesa, errore, elenco), le righe dei livelli con
//  nome, moltiplicatore, costo per risposta e blocco del piano, le stime chieste al server all'apertura e la scelta.
//  Ogni cifra viene dal server: qui non c'è nessun prezzo o moltiplicatore.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaEffortPickerViewModel {
    /// Cosa mostra il foglio.
    enum Screen: Equatable {
        case loading
        case error
        case list
    }

    /// Una riga dell'elenco, già pronta da disegnare.
    struct Row: Identifiable {
        let level: AriaEffortLevel
        let name: String
        /// "2.4×"; nil se il server non manda il moltiplicatore.
        let multiplier: String?
        /// Il badge "High use".
        let showsWarning: Bool
        /// Il piano non offre il livello: riga grigia, con il lucchetto.
        let isLocked: Bool
        /// Il livello della conversazione (anche se il piano non lo offre più).
        let isCurrent: Bool
        /// "Available on Professional"; nil se il server non dice da quale piano.
        let lockReason: String?
        /// "2.4 credits per reply · about 72 a day"; nil senza cifre.
        let costLine: String?

        var id: AriaEffortLevel { level }
    }

    let chat: AriaAgentChat
    let backend: AriaBackend

    /// Le stime del server, una per livello selezionabile.
    private(set) var estimates: [AriaEffortLevel: AriaUsageEstimate] = [:]
    private(set) var isRetrying = false

    init(chat: AriaAgentChat, backend: AriaBackend) {
        self.chat = chat
        self.backend = backend
    }

    private var usage: AriaUsageStore { backend.usage }

    /// Una risposta è partita con il foglio aperto: i livelli non si cambiano più (come il comando nella barra).
    var isSelectionDisabled: Bool { chat.isStreaming }

    /// Il foglio aperto non tiene una config vecchia per sempre: il negozio la rilegge se ha più di 60 s.
    func refreshConfig() async {
        await usage.loadConfig()
    }

    // MARK: - Schermata

    var screen: Screen {
        if let config = usage.config { return config.chatEffortEnabled ? .list : .error }
        return usage.configPhase == .failed ? .error : .loading
    }

    // MARK: - Righe

    var rows: [Row] {
        guard let config = usage.config else { return [] }
        let current = chat.effortLevel
        let listed = config.orderedLevels.map { entry in
            let locked = !entry.info.available
            return Row(
                level: entry.level,
                name: entry.level.title,
                multiplier: entry.info.multiplier.map { AriaCredits.formatMultiplier($0) },
                showsWarning: entry.info.warning,
                isLocked: locked,
                isCurrent: entry.level == current,
                lockReason: locked ? entry.info.unlockTier.map { String(localized: "Available on \(AriaTrialOffer.tierName($0))") } : nil,
                costLine: locked ? nil : costLine(config: config, level: entry.level)?.text
            )
        }
        // Il livello salvato che il piano non elenca più: resta in vista, grigio, col lucchetto e la spunta.
        guard let current, !listed.contains(where: { $0.level == current }) else { return listed }
        let saved = Row(level: current, name: current.title, multiplier: nil, showsWarning: false, isLocked: true,
                        isCurrent: true, lockReason: nil, costLine: nil)
        return (listed + [saved]).sorted { $0.level < $1.level }
    }

    /// Serve la nota "stime" in fondo solo se almeno una riga dice quante risposte al giorno.
    var showsEstimateNote: Bool {
        guard let config = usage.config else { return false }
        return config.orderedLevels.contains { entry in
            entry.info.available && costLine(config: config, level: entry.level)?.replies != nil
        }
    }

    /// "Applies to this conversation. New conversations start at Base."
    var persistFooter: String? {
        guard let level = usage.config?.effort?.defaultLevel else { return nil }
        return String(localized: "Applies to this conversation. New conversations start at \(level.title).")
    }

    /// Letto da VoiceOver su una riga bloccata.
    var lockedHint: String { String(localized: "Not available on your plan") }

    private func costLine(config: AriaUsageConfig, level: AriaEffortLevel) -> AriaEffortCostLine? {
        AriaEffortCostLine.make(config: config, level: level, estimate: estimates[level])
    }

    // MARK: - Stime

    /// Una stima per ogni livello selezionabile, in parallelo, quando l'elenco si apre (il server le tiene 60 s).
    func loadEstimates() async {
        guard screen == .list, let config = usage.config else { return }
        let levels = config.orderedLevels.filter { $0.info.available }.map { $0.level }
        let store = usage
        let found = await withTaskGroup(of: (AriaEffortLevel, AriaUsageEstimate?).self) { group in
            for level in levels {
                group.addTask { (level, await store.estimate(level)) }
            }
            var all: [AriaEffortLevel: AriaUsageEstimate] = [:]
            for await (level, estimate) in group {
                if let estimate { all[level] = estimate }
            }
            return all
        }
        guard !Task.isCancelled else { return }
        estimates = found
    }

    // MARK: - Azioni

    /// `true` se il foglio può chiudersi: il livello scelto (o già in uso). Una riga bloccata non cambia niente.
    @discardableResult
    func select(_ row: Row) -> Bool {
        guard !row.isLocked, !isSelectionDisabled else { return false }
        if !row.isCurrent { chat.chooseEffort(row.level) }
        return true
    }

    /// "Try again": rilegge i livelli (la barra e il foglio si aggiornano da soli).
    func retry() {
        guard !isRetrying else { return }
        isRetrying = true
        Task { [weak self] in
            await self?.backend.usage.loadConfig(force: true)
            self?.isRetrying = false
        }
    }
}
