//
//  AdminUsageKPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una tessera delle cifre della pagina Usage (contratto 3.4), già scritta: valore, riga sotto, barra. Le viste la
//  disegnano e basta.
//

import Foundation

nonisolated struct AdminUsageKPI: Sendable, Equatable, Identifiable {
    nonisolated enum ID: String, Sendable {
        case today, cycle, included, projection, extra
        /// Solo nel modo "day": gli extra di oggi e gli extra del ciclo.
        case extraToday, extraCycle
    }

    /// La barra di una tessera: la quota fino a 1, "over" quando i crediti consumati hanno raggiunto gli inclusi,
    /// la tacca dell'avviso (il primo valore sotto il 100%, "Notice at {pct}%").
    nonisolated struct Bar: Sendable, Equatable {
        /// Da 0 a 1: la quota in percentuale intera, limitata al 100%.
        var fraction: Double
        var isOver: Bool
        /// La posizione della tacca, da 0 a 1; `nil` senza soglia e finché la barra è vuota (una tacca su una barra
        /// vuota è un segno senza niente da misurare).
        var tick: Double?
        var tickLabel: String?
    }

    var id: ID
    var label: String
    /// "—" quando la cifra non c'è (oggi senza lettura, proiezione non ancora disponibile).
    var value: String
    /// "credits", o vuoto quando il valore è "—".
    var unit: String
    /// La riga sotto la cifra; assente quando la cifra che direbbe non è nota.
    var sub: String?
    /// Una seconda riga (l'importo proiettato, solo per un titolare che vede i soldi).
    var sub2: String?
    /// Una nota semplice sotto le righe ("Long conversations count by size", "Resets at 00:00 UTC").
    var note: String?
    /// Crediti extra in addebito: la cifra prende il tono di avviso.
    var isExtra = false
    var bar: Bar?
}
