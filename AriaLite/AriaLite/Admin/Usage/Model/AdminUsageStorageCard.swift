//
//  AdminUsageStorageCard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le schede "Knowledge storage" e "Talk with Aria" (contratto 3.8), già scritte.
//

import Foundation

nonisolated struct AdminUsageStorageCard: Sendable, Equatable {
    /// L'avviso "Storage almost full" / "Over your storage limit" con la sua frase.
    nonisolated struct Notice: Sendable, Equatable {
        var title: String
        var body: String
    }

    var title: String
    /// I byte usati in GB ("2.1 GB").
    var used: String
    /// "of 5 GB", o "used" quando non c'è una capacità dichiarata.
    var ofText: String
    /// "Uploaded files, as of today": su un ciclo chiuso la cifra è quella di oggi.
    var asOfToday: String?
    var hasCapacity: Bool
    /// Da 0 a 1: la parte di barra riempita dal piano e, a destra, quella oltre la capacità (tratteggiata).
    var fillFraction: Double
    var overFraction: Double
    /// Ambra da "warning" (stato del server) in su; "over" oltre la capacità. Mai dedotto dalla quota.
    var tone: AdminUsageTone
    /// "47% used": la quota del server (`share`).
    var percentText: String?
    /// "2.6 GB left" / "0.4 GB over" / "Nothing uploaded yet".
    var leftText: String?
    /// "Includes 1 GB of added storage".
    var addonText: String?
    /// "Your storage is set in your contract.": un titolare senza capacità dichiarata.
    var contractNote: String?
    /// "Almost full" / "Over limit".
    var badge: String?
    var notice: Notice?
    /// Il titolare ha un'azione per scrivere alle vendite (aggiungere spazio, scegliere un piano, contratto).
    var action: AdminUsageMailAction?
}

nonisolated enum AdminUsageStorageState: Sendable, Equatable {
    case loading
    /// Il saldo è letto ma `storage` è `null`, o il saldo è fallito: "could not load" e Riprova.
    case failed
    case ready(AdminUsageStorageCard)
}

nonisolated struct AdminUsageLiveTalkCard: Sendable, Equatable {
    nonisolated enum Kind: Sendable, Equatable {
        /// "{used} of {cap} minutes", una barra e "This cycle. …".
        case open
        /// Ciclo chiuso: "—" e "Minutes used in {month}.": i minuti di un ciclo passato non si servono.
        case closed
        /// Il piano non lo include ma un altro sì: "Not in your plan" e il piano che lo ha.
        case locked
    }

    var kind: Kind
    var title: String
    /// "{used} of {cap} minutes"; "—" su un ciclo chiuso.
    var value: String?
    /// Da 0 a 1; solo per `open`.
    var fraction: Double?
    /// La riga sotto: "This cycle. …", "Minutes used in {month}.", "Included from {plan}: … minutes a month for the company."
    var note: String?
    /// "Not in your plan".
    var lockedChip: String?
    /// "Upgrade to {plan}" ("Choose a plan" in prova): solo un titolare.
    var action: AdminUsageMailAction?
    /// "Ask an owner to change plan.": a un membro, quando la scheda è bloccata (solo nella web, non nel contratto).
    var memberNote: String?
}

nonisolated enum AdminUsageLiveTalkState: Sendable, Equatable {
    /// Nessun piano lo include, o il piano lo ha ma i minuti non si leggono.
    case hidden
    case loading
    case ready(AdminUsageLiveTalkCard)
}
