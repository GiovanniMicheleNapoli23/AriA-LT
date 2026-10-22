//
//  AdminLearnedKnowledgeFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come la sezione Learned knowledge racconta un errore. Un 403 è un ruolo senza permesso (un member
//  che prova a moderare): si dice chiaramente e si resta dentro. Solo la sessione scaduta passa da `backend.handle`.
//

import Foundation

@MainActor
enum AdminLearnedKnowledgeFailure {
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
            return String(localized: "This fact no longer exists. It may have been deleted.")
        case .http(let status, _)? where status == 409:
            return String(localized: "This fact was changed in the meantime. Refresh and try again.")
        default:
            return error.localizedDescription
        }
    }

    static var roleMessage: String {
        String(localized: "Your role isn't allowed to do this. Ask a company owner or admin.")
    }
}
