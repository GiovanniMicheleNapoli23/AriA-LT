//
//  AdminUsageMeters.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Included credits" con i contatori Today e This week (contratto 3.5), già scritta. Solo crediti: ogni
//  ruolo legge la stessa scheda.
//

import Foundation

nonisolated struct AdminUsageMeter: Sendable, Equatable, Identifiable {
    nonisolated enum Kind: Sendable, Equatable {
        case today, week
    }

    var kind: Kind
    var label: String
    /// I crediti usati, scritti.
    var used: String
    /// "of 40 credits".
    var ofIncluded: String
    /// "31% used": la percentuale del server, non limitata a 100.
    var percentText: String
    /// Da 0 a 1: la percentuale intera, limitata al 100% (la barra si ferma piena).
    var fraction: Double
    /// Today: ambra dalla soglia dell'avviso (quota esatta contro soglia esatta), "over" da 100% in su. La settimana
    /// non avvisa mai.
    var tone: AdminUsageTone
    /// La tacca alla soglia dell'avviso (0…1), solo per Today e solo quando è stato usato qualcosa.
    var tick: Double?
    var tickLabel: String?
    /// "Resets at 00:00 UTC", o "Resets Mon, Nov 23 at 00:00 UTC"; assente se la settimana non dice quando riparte.
    var resetText: String?
    /// "{n} credits past today's included", quando Today è "over" e c'è un eccesso.
    var overText: String?

    var id: Kind { kind }
}

nonisolated struct AdminUsageMetersCard: Sendable, Equatable {
    var title: String
    var description: String
    var meters: [AdminUsageMeter]
}

/// Cosa mostra la scheda dei contatori.
nonisolated enum AdminUsageMetersState: Sendable, Equatable {
    /// Ciclo chiuso, un pool o nessun contatore: nessuna scheda.
    case hidden
    /// Il saldo si sta leggendo: la scheda con un segnaposto.
    case loading
    /// Il saldo è fallito: "Today's and this week's credits could not be loaded. Replies are not affected." e Riprova.
    case failed(message: String)
    case ready(AdminUsageMetersCard)
}
