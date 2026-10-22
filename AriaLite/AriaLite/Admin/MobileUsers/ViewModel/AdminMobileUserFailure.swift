//
//  AdminMobileUserFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come la sezione Mobile Users racconta un errore. Un 403 è un ruolo senza permesso; un 404 è un operatore già
//  tolto; un 409 o 422 portano il motivo del server (posti finiti, email già usata). Solo la sessione scaduta
//  passa da `backend.handle`.
//

import Foundation

@MainActor
enum AdminMobileUserFailure {
    /// Il testo da mostrare; `nil` se non c'è niente da dire (richiesta annullata da una nuova).
    static func message(for error: any Error, backend: AriaBackend) -> String? {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
            return error.localizedDescription
        case .http(let status, _)? where status == 403:
            return roleMessage
        case .notOnPhone?:
            return roleMessage
        case .http(let status, _)? where status == 404:
            return String(localized: "This operator no longer exists. Refresh the list.")
        case .http(let status, let detail)? where status == 409 || status == 422:
            return detail.isEmpty ? String(localized: "The server refused this change.") : detail
        default:
            return error.localizedDescription
        }
    }

    static var roleMessage: String {
        String(localized: "Your role isn't allowed to do this. Ask a company owner or admin.")
    }
}
