//
//  AdminUsageAlert.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso che apre la pagina Usage (contratto 3.3), già scritto: tono, titolo, corpo e azioni. Un corpo assente
//  vuol dire che il server non ha mandato una cifra che la frase vuole: il titolo resta da solo.
//

import Foundation

nonisolated struct AdminUsageAlert: Sendable, Equatable {
    var tone: AdminUsageAlertTone
    var title: String
    var body: String?
    var actions: [AdminUsageAlertAction] = []
}

/// Un'azione dell'avviso: tornare al ciclo corrente, andare alla scheda del tetto o scrivere alle vendite.
nonisolated struct AdminUsageAlertAction: Sendable, Equatable, Identifiable {
    nonisolated enum Kind: Sendable, Equatable {
        /// "Back to the current cycle": per tutti.
        case back
        /// "Set a spending limit", "Change limit", "Raise the limit": porta alla scheda del tetto (solo titolari).
        case limit
        /// "Upgrade to {plan}", "Choose a plan": apre la mail alle vendite (solo titolari).
        case plan(URL)
    }

    var kind: Kind
    var label: String

    var id: String { label }
}
