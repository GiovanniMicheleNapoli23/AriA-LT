//
//  AdminWorkOrderFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa dire quando una chiamata degli ordini fallisce. Un 403 vuol dire che il ruolo non può farlo:
//  si spiega, senza sloggare. Solo `.signedOut` passa a `backend.handle`, che chiude la sessione.
//

import Foundation

enum AdminWorkOrderFailure {
    /// Ricerca annullata (filtro cambiato, pull-to-refresh interrotto): non è un errore da mostrare.
    static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        return (error as? URLError)?.code == .cancelled
    }

    /// 403 del server: il ruolo dell'account non ha questa operazione.
    static func isForbidden(_ error: any Error) -> Bool {
        switch error as? AriaError {
        case .notOnPhone?: true
        case .http(let status, _)?: status == 403
        default: false
        }
    }

    /// Il testo da mostrare, o `nil` se non c'è niente da dire (annullata).
    static func message(for error: any Error, backend: AriaBackend) -> String? {
        if isCancellation(error) { return nil }
        if case .signedOut? = error as? AriaError { backend.handle(error) }
        if isForbidden(error) {
            return String(localized: "Your role doesn't allow this. Ask a company admin for access.")
        }
        return error.localizedDescription
    }
}
