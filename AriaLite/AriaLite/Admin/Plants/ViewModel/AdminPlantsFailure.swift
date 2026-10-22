//
//  AdminPlantsFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si mostra un errore della sezione Plants: un messaggio per l'utente, senza dettagli tecnici.
//

import Foundation

struct AdminPlantsFailure: Equatable {
    enum Action { case read, write }

    let message: String
    /// Il ruolo dell'account non ha accesso: riprovare non serve.
    let isForbidden: Bool
    /// Lo stabilimento non esiste (più): un altro utente l'ha eliminato.
    let isNotFound: Bool

    /// `nil` per una chiamata annullata (schermata chiusa): non è un errore da mostrare.
    /// Per gli altri errori del server si mostra il testo che ha mandato (es. "linked data").
    static func from(_ error: any Error, action: Action, backend: AriaBackend) -> Self? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
        case .notOnPhone?, .http(403, _)?:
            let message = switch action {
            case .read:
                String(localized: "Your role doesn't have access to plants. Ask an owner or admin of your company.")
            case .write:
                String(localized: "Your role can't change plants. Ask an owner or admin of your company.")
            }
            return Self(message: message, isForbidden: true, isNotFound: false)
        case .http(404, _)?:
            let message = String(localized: "This plant no longer exists.")
            return Self(message: message, isForbidden: false, isNotFound: true)
        case .http(_, let detail)?:
            let message = detail.isEmpty ? error.localizedDescription : detail
            return Self(message: message, isForbidden: false, isNotFound: false)
        default:
            break
        }
        return Self(message: error.localizedDescription, isForbidden: false, isNotFound: false)
    }
}
