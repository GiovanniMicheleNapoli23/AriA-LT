//
//  AdminCompanySettingsFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa dire quando la cancellazione dei dati fallisce. Un 403 vuol dire che il ruolo non la consente:
//  si spiega, senza uscire dall'account. Solo una sessione scaduta passa da `backend.handle`.
//

import Foundation

struct AdminCompanySettingsFailure: Equatable {
    let message: String

    /// `nil` per una chiamata annullata: non è un errore da mostrare.
    static func from(_ error: any Error, backend: AriaBackend) -> Self? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
            return Self(message: String(localized: "Your session has expired. Sign in again."))
        case .notOnPhone?, .http(403, _)?:
            return Self(message: String(
                localized: "Your role can't delete this data. Ask an owner or admin of your company."))
        case .http(404, _)?:
            return Self(message: String(localized: "Nothing to delete: it may already be gone."))
        default:
            return Self(message: error.localizedDescription)
        }
    }
}
