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
    /// Il rifiuto con un codice delle persone e dell'accesso all'app (`detail.code`), se è quello.
    let refusal: AriaPeopleRefusal?
    /// Il rifiuto con un codice di Roles & Rights (`role_not_found` è un 404: non è "la persona non c'è più").
    let accessRefusal: AriaAccessRefusal?

    init(message: String, isForbidden: Bool, isNotFound: Bool,
         refusal: AriaPeopleRefusal? = nil, accessRefusal: AriaAccessRefusal? = nil) {
        self.message = message
        self.isForbidden = isForbidden
        self.isNotFound = isNotFound
        self.refusal = refusal
        self.accessRefusal = accessRefusal
    }

    /// `nil` per una chiamata annullata (cambio di filtro, schermata chiusa): non è un errore da mostrare.
    static func from(_ error: any Error, action: Action, backend: AriaBackend) -> Self? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
        // Il codice si legge prima dello stato: `role_not_found` è un 404, ma non è una persona sparita.
        case .peopleRefused(let refusal, _)?:
            return Self(message: refusal.message, isForbidden: false, isNotFound: false, refusal: refusal)
        case .accessRefused(let refusal)?:
            return Self(message: refusal.localized, isForbidden: false, isNotFound: false, accessRefusal: refusal)
        case .notOnPhone?, .http(403, _)?, .permissionDenied?:
            let message = switch action {
            case .read: String(localized: "Your role doesn't have access to members. Ask an owner or admin of your company.")
            case .write: String(localized: "Your role can't change members. Ask an owner or admin of your company.")
            }
            return Self(message: message, isForbidden: true, isNotFound: false)
        case .http(404, _)?:
            let message = String(localized: "This member or shift no longer exists.")
            return Self(message: message, isForbidden: false, isNotFound: true)
        // Un 409 o 422 senza un codice noto (es. "Cannot remove the last owner"): il testo del server, com'è.
        case .http(let status, let detail)? where (status == 409 || status == 422) && !detail.isEmpty:
            return Self(message: detail, isForbidden: false, isNotFound: false)
        default:
            break
        }
        return Self(message: error.localizedDescription, isForbidden: false, isNotFound: false)
    }
}
