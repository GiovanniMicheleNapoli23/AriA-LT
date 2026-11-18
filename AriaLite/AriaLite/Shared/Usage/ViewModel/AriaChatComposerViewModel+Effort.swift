//
//  AriaChatComposerViewModel+Effort.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il livello di effort nel composer: la voce del "+" (caricamento, livello e moltiplicatore, errore, nascosta),
//  la pillola nella barra quando il livello non è quello di partenza e la lettura dei livelli all'apertura.
//  Il livello e i suoi numeri vengono dal server (AriaUsageStore) e dalla conversazione (AriaAgentChat).
//

import Foundation

extension AriaChatComposerViewModel {
    /// La voce "Effort" del "+".
    enum EffortEntry: Equatable {
        /// L'azienda non ha l'effort per la chat, o questo telefono non lo mostra.
        case hidden
        /// "Loading effort levels", spenta.
        case loading
        /// "Effort: High · 2.4×".
        case ready(String)
        /// "Effort: Base": il foglio si apre già sull'errore.
        case failed(String)
    }

    var effortEntry: EffortEntry {
        let usage = backend.usage
        guard !usage.isUnavailable else { return .hidden }
        if let config = usage.config {
            return config.chatEffortEnabled ? .ready(effortMenuTitle(config)) : .hidden
        }
        if usage.configPhase == .failed {
            return .failed(String(localized: "Effort: \(AriaEffortLevel.base.title)"))
        }
        return .loading
    }

    /// Durante una risposta il livello non si cambia da qui.
    var isEffortDisabled: Bool { chat.isStreaming }

    /// La pillola nella barra: solo quando il livello non è quello di partenza.
    var effortPillTitle: String? {
        let usage = backend.usage
        guard !usage.isUnavailable, let config = usage.config, config.chatEffortEnabled,
              let level = chat.effortLevel, level != config.effort?.defaultLevel else { return nil }
        return String(localized: "Effort: \(level.title)")
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

    private func effortMenuTitle(_ config: AriaUsageConfig) -> String {
        let level = chat.effortLevel ?? .base
        if let multiplier = config.effort?.levels[level]?.multiplier {
            return String(localized: "Effort: \(level.title) · \(AriaCredits.formatMultiplier(multiplier))")
        }
        return String(localized: "Effort: \(level.title)")
    }
}

extension AriaChatComposerViewModel {
    /// L'icona dell'effort, nel "+" e nella pillola.
    static let effortIcon = "gauge.with.dots.needle.67percent"
}
