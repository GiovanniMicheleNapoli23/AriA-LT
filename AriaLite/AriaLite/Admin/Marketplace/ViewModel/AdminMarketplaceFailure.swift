//
//  AdminMarketplaceFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come la sezione Marketplace racconta un errore. Un 403 è un ruolo senza permesso (un member che
//  gestisce un connettore): si dice chiaramente e si resta dentro. Solo la sessione scaduta passa da
//  `backend.handle`. Gli altri rifiuti del server (409, 501, 503) hanno già un testo che spiega cosa fare.
//

import Foundation

@MainActor
enum AdminMarketplaceFailure {
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
            return String(localized: "This connector no longer exists. Pull to refresh the list.")
        case .http(let status, let detail)? where status == 409:
            return detail.isEmpty
                ? String(localized: "This connector signs in with OAuth. Use Connect instead of a key.")
                : detail
        default:
            return error.localizedDescription
        }
    }

    static var roleMessage: String {
        String(localized: "Your role isn't allowed to do this. Ask a company owner or admin.")
    }
}
