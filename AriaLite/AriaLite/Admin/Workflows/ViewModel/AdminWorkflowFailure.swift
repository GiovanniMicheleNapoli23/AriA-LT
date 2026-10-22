//
//  AdminWorkflowFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come la sezione Workflows racconta un errore. 409 (o 412) = qualcuno ha cambiato il flusso mentre lo
//  guardavi: si dice e si ricarica. Un 403 è un ruolo senza permesso. Solo la sessione scaduta passa da
//  `backend.handle`.
//

import Foundation

@MainActor
enum AdminWorkflowFailure {
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
            return String(localized: "This flow no longer exists. It may have been deleted.")
        case .http(let status, _)? where status == 409 || status == 412:
            return conflictMessage
        default:
            return error.localizedDescription
        }
    }

    /// Qualcun altro ha cambiato il flusso: la revisione che avevamo non vale più.
    static func isConflict(_ error: any Error) -> Bool {
        if case .http(let status, _)? = error as? AriaError { return status == 409 || status == 412 }
        return false
    }

    static func isNotFound(_ error: any Error) -> Bool {
        if case .http(let status, _)? = error as? AriaError { return status == 404 }
        return false
    }

    static var conflictMessage: String {
        String(localized: """
            This flow was changed by someone else in the meantime. \
            It has been reloaded: check it and try again.
            """)
    }

    static var roleMessage: String {
        String(localized: "Your role isn't allowed to do this. Ask a company owner or admin.")
    }
}
