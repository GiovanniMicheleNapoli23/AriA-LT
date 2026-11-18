//
//  AriaCreditsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I crediti nel profilo: lo stato della card (nascosta, in attesa, pronta, in errore), il testo e l'anello,
//  e la rilettura del saldo (ogni 60 s mentre il profilo è aperto e quando l'app torna in primo piano).
//  Non calcola mai il saldo né lo stato: li legge dal server (AriaAllowance, AriaAllowanceSummary).
//

import Observation
import SwiftUI

@MainActor
@Observable
final class AriaCreditsViewModel {
    /// Cosa mostra la card. Finché il primo saldo non arriva resta nascosta (niente segnaposto che lampeggia).
    enum State: Equatable {
        case hidden
        case loading
        case ready
        case failed
    }

    /// La card già pronta da disegnare.
    struct Card {
        let headline: String
        let subline: String?
        /// L'arco dell'anello, 0...1.
        let fraction: Double
        /// Senza una quota giornaliera l'anello è un cerchio pieno e spento.
        let isMuted: Bool
        let tone: AriaAllowanceSummary.Tone
    }

    let backend: AriaBackend

    /// Secondi tra due letture del saldo mentre il profilo è aperto.
    static let pollInterval: Duration = .seconds(60)

    init(backend: AriaBackend) {
        self.backend = backend
    }

    var usage: AriaUsageStore { backend.usage }

    // MARK: - Stato

    /// Il saldo già letto dalle view: `nil` se la funzione è spenta o non c'è ancora una cifra.
    var summary: AriaAllowanceSummary? {
        guard !usage.isUnavailable, let allowance = usage.allowance else { return nil }
        return AriaAllowanceSummary.make(allowance, canManagePlan: usage.config?.canManagePlan ?? false)
    }

    var state: State {
        guard !usage.isUnavailable else { return .hidden }
        if usage.allowance != nil { return summary == nil ? .hidden : .ready }
        return usage.allowancePhase == .failed ? .failed : .loading
    }

    /// La card c'è (pronta o con l'errore); le altre volte il profilo non le lascia posto.
    var isVisible: Bool { state == .ready || state == .failed }
    var isFailed: Bool { state == .failed }

    var card: Card? {
        guard let summary else { return nil }
        return Card(
            headline: summary.headline,
            subline: summary.subline,
            fraction: summary.ringFraction ?? 1,
            isMuted: summary.ringFraction == nil,
            tone: summary.tone
        )
    }

    /// "27.6 credits available · refills in 3 h. Open credit details." (o l'errore, se il saldo non si legge).
    var cardAccessibilityLabel: String {
        guard !isFailed, let card else {
            return [String(localized: "Credits unavailable"), String(localized: "Chat keeps working")].joined(separator: ". ")
        }
        let spoken = [card.headline, card.subline].compactMap { $0 }.joined(separator: " · ")
        return String(localized: "\(spoken). Open credit details.")
    }

    /// Sulla card in errore il tocco riprova.
    var cardAccessibilityHint: String { isFailed ? String(localized: "Try again") : "" }

    /// Normale = accento, avviso = ambra, tetto raggiunto = grigio. Mai rosso.
    func tint(_ tone: AriaAllowanceSummary.Tone) -> Color {
        switch tone {
        case .normal: Color.liteAccent
        case .warning: Color.liteWarning
        case .capped: Color.secondary
        }
    }

    /// L'avviso: informazione = accento, avviso = ambra, critico (tetto raggiunto) = grigio. Mai rosso.
    func tint(_ severity: AriaAllowanceSummary.Alert.Severity) -> Color {
        switch severity {
        case .info: Color.liteAccent
        case .warning: Color.liteWarning
        case .critical: Color.secondary
        }
    }

    /// "Ends 3 Dec" sotto le barre, solo se la barra del ciclo non lo dice già.
    var trialNote: String? {
        guard let summary, let line = summary.trialLine, line != summary.cycle?.resets else { return nil }
        return line
    }

    // MARK: - Rilettura

    /// Rilegge il saldo ora; il negozio tiene da solo l'errore (nessuna cifra) e non tocca la chat.
    func refresh() async {
        guard !usage.isUnavailable else { return }
        await usage.refreshAllowance()
    }

    /// Dal profilo: una lettura subito e poi ogni 60 s, finché la vista (e il suo `.task`) vive.
    func poll() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    /// Tornando in primo piano il saldo si rilegge (il ciclo di `poll` riparte da solo solo ogni minuto).
    func scenePhaseChanged(_ phase: ScenePhase) {
        guard phase == .active else { return }
        Task { await refresh() }
    }

    /// "Try again" dalla card in errore.
    func retry() {
        Task { await refresh() }
    }
}
