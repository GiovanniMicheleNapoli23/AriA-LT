//
//  AdminReportLoad.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di una sezione della pagina: valore, errore e caricamento in corso, indipendenti dalle altre.
//  Un aggiornamento fallito non toglie i dati già arrivati.
//

import Foundation

nonisolated struct AdminReportLoad<Value: Sendable>: Sendable {
    private(set) var value: Value?
    private(set) var errorMessage: String?
    var isLoading = false

    /// Chiude un caricamento: un errore tiene i dati già arrivati, un annullamento non cambia niente.
    mutating func finish(_ outcome: AdminReportOutcome<Value>) {
        isLoading = false
        switch outcome {
        case .value(let value):
            self.value = value
            errorMessage = nil
        case .failure(let message):
            errorMessage = message
        case .cancelled:
            break
        }
    }

    /// Cambia il valore già arrivato (es. un widget eliminato), senza toccare errore e caricamento.
    mutating func update(_ change: (inout Value) -> Void) {
        guard var current = value else { return }
        change(&current)
        value = current
    }

    mutating func clear() {
        self = AdminReportLoad()
    }
}

/// L'esito di una richiesta della pagina.
nonisolated enum AdminReportOutcome<Value: Sendable>: Sendable {
    case value(Value)
    case failure(String)
    /// Richiesta interrotta da un'altra: niente da mostrare.
    case cancelled
}
