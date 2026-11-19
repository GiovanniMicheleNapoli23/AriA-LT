//
//  AdminUsageSpendCapCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Spending limit" del titolare (contratto 5.1) già scritta: i tre stati (prova, nessun limite, limite in
//  vigore), il modulo del campo e la conferma di "Lower limit". Le viste leggono questi modelli e inoltrano le azioni.
//

import Foundation

nonisolated struct AdminUsageSpendCapCard: Sendable, Equatable {
    /// "Spending limit".
    var title: String
    /// A cosa serve il limite (con le parole di "stop" dove il piano si ferma).
    var description: String
    var content: Content

    nonisolated enum Content: Sendable, Equatable {
        /// Il limite si sta leggendo.
        case loading
        /// "The spending limit could not be loaded. Replies are not affected." e Riprova.
        case failed(String)
        case trial(Trial)
        case noLimit(NoLimit)
        case inForce(InForce)
    }

    /// La prova gratuita: €0, bloccato, solo "Choose a plan". Nessun campo e nessun bottone di salvataggio.
    nonisolated struct Trial: Sendable, Equatable {
        var amount: String
        /// "Free trial".
        var chip: String
        /// "per cycle · since {date}".
        var since: String?
        /// `trialBody`, oppure `trialReachedBody` quando il saldo è `capped`.
        var body: String
        /// Solo un titolare con un indirizzo delle vendite.
        var choosePlan: AdminUsageMailAction?
    }

    /// Nessun limite: il chip, la frase del prezzo e (nella vista) il modulo.
    nonisolated struct NoLimit: Sendable, Equatable {
        /// "No limit".
        var chip: String
        /// "Extra credits are billed at {price} each, with no upper limit."; `nil` senza prezzo.
        var body: String?
    }

    /// Un limite in vigore.
    nonisolated struct InForce: Sendable, Equatable {
        var amount: String
        /// "= 3,125 credits".
        var credits: String?
        /// "In force" o "Reached".
        var chip: String
        var isReached: Bool
        /// "per cycle · since {date} · at {price} per credit".
        var subline: String?
        var used: Used?
        /// La frase del 80% (con le parole di "stop" dove serve); `nil` se non c'è o manca una cifra.
        var warnedNote: String?
        var reachedNote: String?
        /// "This limit is always on. …": dove il piano ha un limite di partenza.
        var alwaysOnNote: String?
        /// "Change", "Change limit" o "Raise the limit".
        var changeLabel: String
        /// "Raise the limit" è il bottone principale della scheda.
        var changeIsProminent: Bool
        /// "Remove limit": solo per un limite sopra 0 e senza limite di partenza del piano.
        var canRemove: Bool
        var removeLabel: String
        /// "The limit was not saved. Try again." dopo un salvataggio (o una rimozione) fallito.
        var saveError: String?
    }

    /// "{billed} of {limit} used this cycle · {credits} of {credits} credits" con la barra.
    nonisolated struct Used: Sendable, Equatable {
        var text: String
        /// La barra, da 0 a 1; `nil` quando il server non ha mandato la quota (`dashboard.spend_cap.percent`).
        var fill: Double?
        var tone: AdminUsageTone
    }
}

/// Il campo "Limit per cycle (EUR)" con quello che serve attorno.
nonisolated struct AdminUsageSpendCapForm: Sendable, Equatable {
    /// "Limit per cycle (EUR)".
    var label: String
    /// Il testo del campo: quello scritto, altrimenti il limite in vigore o il suggerimento.
    var text: String
    /// "Enter an amount of {minimum} or more." dopo un invio non valido.
    var invalidText: String?
    /// "= {credits} credits at {price} per credit": solo mentre si modifica un limite in vigore.
    var preview: String?
    /// "Suggested: …" e "Set €0 to never pay for extra credits." (o "Minimum {amount}.").
    var help: String?
    /// "Saving…", "Save" o "Set limit".
    var saveTitle: String
    /// Disabilitato mentre si salva e finché il saldo non è letto.
    var saveEnabled: Bool
    var showsCancel: Bool
    /// Il saldo non si è letto: "What this cycle has used could not be loaded, so the limit cannot be saved yet." e Riprova.
    var usedError: String?
    var saveError: String?
}

/// "Lower the limit below what's already used?": il nuovo limite è sotto quanto il ciclo ha già addebitato.
nonisolated struct AdminUsageSpendCapConfirmation: Sendable, Equatable {
    var title: String
    var body: String
    /// "Lower limit".
    var button: String
    /// L'importo da mandare se si conferma.
    var amount: Decimal
}
