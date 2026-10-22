//
//  AdminMembersFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa dire quando una chiamata dei membri fallisce. Un 403 vuol dire che il ruolo non lo consente:
//  si spiega, senza uscire dall'account. Solo una sessione scaduta passa da `backend.handle`.
//

import Foundation

struct AdminMembersFailure: Equatable {
    enum Action { case read, write }

    let message: String
    /// Il ruolo dell'account non ha accesso: riprovare non serve.
    let isForbidden: Bool
    /// L'elemento non esiste (più): un altro utente l'ha eliminato.
    let isNotFound: Bool

    /// `nil` per una chiamata annullata (cambio di filtro, schermata chiusa): non è un errore da mostrare.
    static func from(_ error: any Error, action: Action, backend: AriaBackend) -> Self? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
        case .notOnPhone?, .http(403, _)?:
            let message = switch action {
            case .read: String(localized: "Your role doesn't have access to members. Ask an owner or admin of your company.")
            case .write: String(localized: "Your role can't change members. Ask an owner or admin of your company.")
            }
            return Self(message: message, isForbidden: true, isNotFound: false)
        case .http(404, _)?:
            let message = String(localized: "This member or shift no longer exists.")
            return Self(message: message, isForbidden: false, isNotFound: true)
        default:
            break
        }
        return Self(message: error.localizedDescription, isForbidden: false, isNotFound: false)
    }
}
