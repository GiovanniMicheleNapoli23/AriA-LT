//
//  AdminAuditLogFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come lo storico racconta un errore. Un 403 è un ruolo senza permesso: si dice chiaramente e si resta dentro.
//  Solo la sessione scaduta passa da `backend.handle`.
//

import Foundation

@MainActor
enum AdminAuditLogFailure {
    /// Il testo da mostrare; `nil` se non c'è niente da dire (richiesta annullata da una nuova).
    static func message(for error: any Error, backend: AriaBackend) -> String? {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
            return error.localizedDescription
        case .http(let status, _)? where status == 403:
            return String(localized: "Your role doesn't allow this. Ask a company owner or admin.")
        case .notOnPhone?:
            return String(localized: "Your role doesn't allow this. Ask a company owner or admin.")
        default:
            return error.localizedDescription
        }
    }
}
