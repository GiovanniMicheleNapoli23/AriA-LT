//
//  AriaLearningOutcomeViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La logica del pannello che prende il posto della domanda di Real-time Learning appena risposta:
//  cosa dire (sta imparando, ha imparato, in revisione), il contesto da rivedere e l'avviso agli admin
//  per i fatti ancora in proposta. L'esito cambia mentre si salva: arriva dalla vista a ogni lettura.
//

import Foundation
import Observation

@MainActor
@Observable
final class AriaLearningOutcomeViewModel {
    let chat: AriaAgentChat

    /// Cosa dice l'intestazione.
    enum Phase: Equatable {
        /// Aria sta salvando la risposta.
        case saving
        /// Aggiunto alla conoscenza dell'azienda.
        case learned
        /// Salvato come proposta: serve l'approvazione di un admin.
        case proposed
    }

    // MARK: - State

    private(set) var showContext = false
    /// I fatti per cui gli admin sono già stati avvisati.
    private(set) var notified: Set<String> = []
    private(set) var notifying = false

    init(chat: AriaAgentChat) {
        self.chat = chat
    }

    // MARK: - Derived

    func phase(_ outcome: AriaLearningOutcome) -> Phase {
        if outcome.isSaving { return .saving }
        return outcome.learnedSomething || outcome.items.isEmpty ? .learned : .proposed
    }

    /// I fatti in proposta di cui gli admin non sono ancora stati avvisati.
    func pending(_ outcome: AriaLearningOutcome) -> [String] {
        outcome.items.filter(\.isProposed).compactMap(\.factId).filter { !notified.contains($0) }
    }

    func canNotify(_ outcome: AriaLearningOutcome) -> Bool {
        !pending(outcome).isEmpty && chat.canConfirmMemory
    }

    func showsItems(_ outcome: AriaLearningOutcome) -> Bool {
        !outcome.items.isEmpty || showContext
    }

    /// Il fatto nella lingua dell'operatore (arriva dopo: intanto l'originale).
    func text(_ item: AriaMemoryValidationResponse.Item) -> String {
        chat.translated(item.content, id: item.factId)
    }

    // MARK: - Actions

    func toggleContext() {
        showContext.toggle()
    }

    func requestTranslations(_ outcome: AriaLearningOutcome) {
        guard !outcome.items.isEmpty else { return }
        chat.requestTranslations(outcome.items.map { ($0.factId, $0.content) })
    }

    func notify(_ outcome: AriaLearningOutcome) {
        let ids = pending(outcome)
        notifying = true
        Task {
            if await chat.notifyLearning(ids) { notified.formUnion(ids) }
            notifying = false
        }
    }

    func dismiss() {
        chat.dismissLearningOutcome()
    }
}
