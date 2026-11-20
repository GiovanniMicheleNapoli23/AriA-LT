//
//  AriaChatComposerViewModel+Effort.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'effort nel composer: la riga sotto il campo che compare con la tastiera (il menu dei livelli, con
//  caricamento, errore e nascosto, accanto all'icona dei connettori), la scelta del livello senza chiudere la
//  tastiera e la lettura dei livelli all'apertura. Il livello e i suoi numeri vengono dal server (AriaUsageStore) e dalla conversazione
//  (AriaAgentChat); righe, stime e scelta sono quelle del foglio "Effort" (AriaEffortPickerViewModel).
//

import Foundation

extension AriaChatComposerViewModel {
    /// Il comando dell'effort sotto il campo.
    enum EffortEntry: Equatable {
        /// L'azienda non ha l'effort per la chat, o questo telefono non lo mostra.
        case hidden
        /// I livelli si stanno leggendo: comando spento.
        case loading
        /// Il menu dei livelli: "Effort 1×" al livello di partenza, "High 2.4×" sugli altri.
        case ready(String)
        /// "Effort 1×" (le risposte usano Base): il tocco apre il foglio già sull'errore, con "Try again".
        case failed(String)
    }

    var effortEntry: EffortEntry {
        let usage = backend.usage
        guard !usage.isUnavailable else { return .hidden }
        if let config = usage.config {
            return config.chatEffortEnabled ? .ready(effortChipTitle(config)) : .hidden
        }
        if usage.configPhase == .failed {
            return .failed("\(String(localized: "Effort")) \(AriaCredits.formatMultiplier(1))")
        }
        return .loading
    }

    /// Al livello di partenza (Base) "Effort 1×", sugli altri il nome: "High 2.4×". Senza moltiplicatore dal server
    /// solo il nome (Base vale sempre 1×).
    private func effortChipTitle(_ config: AriaUsageConfig) -> String {
        let level = chat.effortLevel ?? .base
        let isStart = level == .base || level == config.effort?.defaultLevel
        let name = isStart ? String(localized: "Effort") : level.title
        let multiplier = config.effort?.levels[level]?.multiplier ?? (level == .base ? 1 : nil)
        guard let multiplier else { return name }
        return "\(name) \(AriaCredits.formatMultiplier(multiplier))"
    }

    /// Durante una risposta il livello non si cambia da qui.
    var isEffortDisabled: Bool { chat.isStreaming }

    // MARK: - Riga sotto il campo

    /// La riga compare con la tastiera, se l'effort c'è (e la barra non è bloccata da una pausa).
    /// Con la riga in vista anche il "+" scende lì, accanto agli altri pulsanti. Col popover dei connettori aperto
    /// (si apre dal "+") la riga resta: se il "+" cambiasse posto il popover perderebbe l'ancora.
    var showsUsageRow: Bool {
        (isInputFocused || showConnectors) && !isLocked && effortEntry != .hidden
    }

    /// Con la tastiera chiusa, sopra il campo: il livello quando non è quello di partenza (costa di più o di meno).
    /// Con la tastiera aperta lo dice già il menu sotto il campo.
    var effortPillTitle: String? {
        let usage = backend.usage
        guard !isInputFocused, !showConnectors, !usage.isUnavailable, let config = usage.config, config.chatEffortEnabled,
              let level = chat.effortLevel, level != config.effort?.defaultLevel else { return nil }
        return String(localized: "Effort: \(level.title)")
    }

    /// Le righe del menu: gli stessi livelli del foglio, con moltiplicatore, costo e blocco del piano.
    var effortRows: [AriaEffortPickerViewModel.Row] { effortPicker.rows }

    /// "High · 2.4×".
    func effortTitle(_ row: AriaEffortPickerViewModel.Row) -> String {
        guard let multiplier = row.multiplier else { return row.name }
        return "\(row.name) · \(multiplier)"
    }

    /// Sotto il nome: "High use · 2.4 credits per reply · about 72 a day", o perché il piano non lo offre.
    func effortSubtitle(_ row: AriaEffortPickerViewModel.Row) -> String? {
        if row.isLocked { return row.lockReason ?? effortPicker.lockedHint }
        let parts = [row.showsWarning ? String(localized: "High use") : nil, row.costLine].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// La scelta dal menu: la tastiera resta aperta. Un livello bloccato, o una risposta in corso, non cambiano niente.
    func selectEffort(_ row: AriaEffortPickerViewModel.Row) {
        effortPicker.select(row)
    }

    /// Quando chiedere le stime per il menu: con la tastiera aperta e i livelli letti.
    var effortEstimatesKey: Bool {
        isInputFocused && effortPicker.screen == .list
    }

    /// Le stime del menu (il server le tiene 60 s): solo quando la riga è in vista.
    func loadEffortEstimates() async {
        guard effortEstimatesKey else { return }
        await effortPicker.loadEstimates()
    }

    /// I livelli si leggono quando il composer compare (il negozio li tiene 60 s e li rilegge al cambio azienda).
    func loadEffortConfig() async {
        guard backend.isReady else { return }
        await backend.usage.loadConfig()
    }

    /// Per VoiceOver: "Effort: High, 2.4 times", senza il segno ×; con un livello che il piano non offre più lo dice.
    var effortAccessibilityLabel: String? {
        let usage = backend.usage
        guard !usage.isUnavailable, let config = usage.config, config.chatEffortEnabled else { return nil }
        let level = chat.effortLevel ?? .base
        let info = config.effort?.levels[level]
        let title = level.title
        if let info, !info.available {
            return String(localized: "Effort: \(title), not available on your plan")
        }
        if let multiplier = info?.multiplier {
            let spoken = multiplier.formatted(Decimal.FormatStyle(locale: .autoupdatingCurrent).precision(.fractionLength(0...2)))
            return String(localized: "Effort: \(title), \(spoken) times")
        }
        return String(localized: "Effort: \(title)")
    }
}

extension AriaChatComposerViewModel {
    /// L'icona dell'effort, sotto il campo e nel foglio.
    static let effortIcon = "gauge.with.dots.needle.67percent"
}
