//
//  AdminCategoriesFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa dire quando una chiamata delle categorie fallisce. Un 403 vuol dire che il ruolo non lo consente:
//  si spiega, senza uscire dall'account. Solo una sessione scaduta passa da `backend.handle`.
//

import Foundation

struct AdminCategoriesFailure: Equatable {
    enum Action { case read, write }

    let message: String
    /// La categoria non esiste (più): un altro utente l'ha eliminata.
    let isNotFound: Bool

    /// `nil` per una chiamata annullata (schermata chiusa, nuova ricerca): non è un errore da mostrare.
    static func from(_ error: any Error, action: Action, backend: AriaBackend) -> Self? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
        case .notOnPhone?, .http(403, _)?:
            let message = switch action {
            case .read:
                String(localized: "Your role doesn't have access to categories. Ask an owner or admin of your company.")
            case .write: String(localized: "Your role can't change categories. Ask an owner or admin of your company.")
            }
            return Self(message: message, isNotFound: false)
        case .http(404, _)?:
            return Self(message: String(localized: "This category no longer exists."), isNotFound: true)
        default:
            break
        }
        return Self(message: error.localizedDescription, isNotFound: false)
    }
}
