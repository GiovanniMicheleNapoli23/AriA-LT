//
//  AdminCraftedAriaBlock.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  I tipi di "Modifica con Aria" (edit-with-aria.ts della web): i blocchi con cui un documento arriva ad
//  Aria (un testo, o una tabella con colonne e righe), le modifiche che Aria rimanda, la proposta intera
//  e gli errori. Solo dati: il testo dei prompt, la lettura della risposta e il taglio in parti stanno
//  negli altri file AdminCraftedAria*.
//

import Foundation

/// Un pezzo del documento come lo legge Aria. L'id è la chiave con cui la risposta lo richiama.
nonisolated enum AdminCraftedAriaBlock: Hashable, Sendable {
    case text(id: String, text: String)
    case table(id: String, columns: [AdminCraftedColumn], rows: [AdminCraftedEditedRow])

    var id: String {
        switch self {
        case .text(let id, _), .table(let id, _, _): id
        }
    }
}

/// Un blocco cambiato da Aria: il testo nuovo per intero, o le righe nuove di una tabella per intero.
nonisolated enum AdminCraftedAriaChange: Hashable, Sendable {
    /// Una riga di tabella: `id` è `nil` per una riga che Aria ha aggiunto (o con un id che non esiste).
    nonisolated struct Row: Hashable, Sendable {
        var id: String?
        var cells: [String: AdminCraftedCell]
    }

    case text(id: String, text: String)
    case rows(id: String, rows: [Row])

    var id: String {
        switch self {
        case .text(let id, _), .rows(let id, _): id
        }
    }
}

/// Quello che Aria propone: i blocchi cambiati, la sua riga su cosa ha fatto (o perché non ha fatto niente) e
/// la conversazione in cui l'ha fatto — quella a cui "Apri la conversazione" porta.
nonisolated struct AdminCraftedAriaProposal: Hashable, Sendable {
    var changes: [AdminCraftedAriaChange]
    var note: String?
    var sessionId: String
}

/// La risposta di una parte: le modifiche, oppure "serve leggere anche le altre parti".
nonisolated struct AdminCraftedAriaAnswer: Hashable, Sendable {
    var changes: [AdminCraftedAriaChange]
    var note: String?
    var needsWhole = false
}

/// Perché una richiesta non è diventata una proposta.
nonisolated enum AdminCraftedAriaError: Error, Sendable {
    /// Aria ha risposto ma non con una modifica: le sue parole, o — se non ha scritto niente — cosa ha fatto il turno.
    case noEdit(text: String, reason: String?)
    /// Il documento non entra in una sola conversazione di Aria (finestra di contesto quasi piena).
    case tooLong
    /// L'istruzione da sola riempie il corpo della richiesta: non resta posto per il documento.
    case instructionTooLong
}

/// Il corpo del PATCH con cui la sessione di una richiesta prende un nome e esce dall'apprendimento
/// (updateSession della web): le richieste di modifica non sono conversazioni da cui imparare.
nonisolated struct AdminCraftedAriaSessionPatch: Encodable, Sendable {
    var title: String
    /// "archived" per le sessioni in più di un documento lungo; assente per quella principale.
    var status: String?
    var scenarioOptOut = true

    enum CodingKeys: String, CodingKey {
        case title, status
        case scenarioOptOut = "scenario_opt_out"
    }
}
