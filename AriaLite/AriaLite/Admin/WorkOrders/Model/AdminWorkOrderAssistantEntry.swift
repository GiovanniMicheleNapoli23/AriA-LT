//
//  AdminWorkOrderAssistantEntry.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una risposta dell'assistente AI in questa sessione: cosa si è chiesto, cosa ha risposto e se i valori
//  proposti sono già stati scritti sull'ordine. La cronologia vive solo finché il foglio è aperto.
//

import Foundation

nonisolated struct AdminWorkOrderAssistantEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    /// Il valore di `action` mandato al server (anche uno suggerito dal server stesso).
    let action: String
    let title: String
    let systemImage: String
    /// La domanda libera, se c'era.
    let prompt: String?
    let date: Date
    let answer: AdminWorkOrderAIAnswer
    /// Cosa è già stato scritto sull'ordine da questa risposta.
    var applied: Set<AdminWorkOrderAssistantApply> = []

    init(action: String, title: String, systemImage: String, prompt: String?, answer: AdminWorkOrderAIAnswer,
         date: Date = .now) {
        id = UUID()
        self.action = action
        self.title = title
        self.systemImage = systemImage
        self.prompt = prompt
        self.answer = answer
        self.date = date
    }
}

/// I modi di portare una risposta sull'ordine (PATCH).
nonisolated enum AdminWorkOrderAssistantApply: Hashable, Sendable {
    /// I campi proposti (titolo, descrizione, priorità, tipo, categoria, durata, note).
    case fields
    /// Il testo della risposta diventa la descrizione.
    case textAsDescription
    /// Passi, sicurezza, attrezzi e ricambi (o il testo) in fondo alle note: la procedura non si modifica da qui.
    case appendToNotes
}

/// Una riga "campo → valore proposto" nella scheda di una risposta.
nonisolated struct AdminWorkOrderAssistantFieldRow: Identifiable, Hashable, Sendable {
    let label: String
    let value: String
    /// Il valore proposto è uguale a quello attuale.
    let unchanged: Bool

    var id: String { label }
}

/// Un'azione rifiutata dal server: il messaggio e, se li ha detti, i valori di `action` validi.
nonisolated struct AdminWorkOrderAssistantFailure: Equatable, Sendable {
    let message: String
    let validActions: [String]
}
