//
//  AdminCraftedAriaPanelModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Quello che il pannello "Modifica con Aria" riceve dal lettore, uguale per artifact e rapporto: lo
//  stato (aperto, istruzione, cosa è scelto), i blocchi fra cui scegliere, il riassunto della proposta in
//  pagina e le azioni. Il pannello non conosce né l'uno né l'altro: mostra e chiama.
//

import Foundation

/// Lo stato del pannello, nel lettore: se è aperto, cosa si sta scrivendo e cosa si è scelto (vuoto = tutto).
nonisolated struct AdminCraftedAriaPanelState: Hashable, Sendable {
    var isOpen = false
    var instruction = ""
    /// Gli id dei blocchi scelti: id di messaggio (artifact) o indice di paragrafo (rapporto).
    var scope: Set<String> = []
    var showsScope = false
}

/// Un blocco fra cui scegliere cosa cambia Aria.
nonisolated struct AdminCraftedAriaChoice: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
}

/// La proposta in pagina: di quanto cambia il documento, e come si chiama la versione se la si accetta.
nonisolated struct AdminCraftedAriaProposalSummary: Hashable, Sendable {
    let changes: String
    let acceptTitle: String
}

/// Cosa il pannello può far fare al lettore.
struct AdminCraftedAriaActions {
    var send: () -> Void
    var stop: () -> Void
    var accept: () -> Void
    var discard: () -> Void
    var openChat: () -> Void
    /// Nasconde il pannello (la richiesta e la proposta restano).
    var hide: () -> Void
}

nonisolated enum AdminCraftedAriaText {
    /// Un testo su una riga e accorciato, per riconoscere il blocco in un elenco.
    static func preview(_ text: String, limit: Int = 140) -> String {
        // Solo l'inizio: un testo lungo non si scorre tutto per riconoscerlo in un elenco.
        let flat = String(text.prefix(limit * 4)).split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
    }

    /// "Tutto il documento", o quanti blocchi sono scelti.
    static func scopeText(count: Int) -> String {
        count == 0 ? String(localized: "The whole document") : String(localized: "\(count) selected")
    }
}
