//
//  AriaPlantGuard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Cosa offre l'avviso "manca lo stabilimento" sopra il composer: senza stabilimento il backend non risponde.
//

import Foundation

enum AriaPlantGuard: Equatable {
    /// Ci sono stabilimenti: se ne sceglie uno.
    case choose
    /// Nessuno stabilimento e l'account li gestisce (sezione Plants della sidebar dell'admin): se ne crea uno da qui.
    case create
    /// Nessuno stabilimento e nessuna sezione Plants (layout dell'operatore): lo aggiunge un owner o un admin.
    case askAdmin
}
