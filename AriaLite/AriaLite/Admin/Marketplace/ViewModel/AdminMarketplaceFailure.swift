//
//  AdminMarketplaceFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come la sezione Marketplace racconta un errore, secondo la tabella dei connettori del contratto: il
//  `message` del server è scritto per la persona e si mostra (409, 410, 502); 503 è Composio non raggiungibile.
//  Un 403 `operation_forbidden` vuol dire che l'accesso è cambiato: si rileggono /v1/companies e /v1/me (§11).
//  Solo la sessione scaduta passa da `backend.handle`.
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
        case .http(403, _)?, .notOnPhone?:
            Task { await backend.refreshAccess() }
            return roleMessage
        case .http(404, _)?:
            return String(localized: "This connector no longer exists. Pull to refresh the list.")
        case .http(409, let detail)?:
            return detail.isEmpty
                ? String(localized: "This connector signs in with OAuth. Use Connect instead of a key.")
                : detail
        case .http(410, let detail)?:
            return detail.isEmpty ? String(localized: "This sign-in link was already used. Start again.") : detail
        case .http(502, let detail)? where !detail.isEmpty && !detail.hasPrefix("<"):
            return detail
        case .http(502, _)?, .http(503, _)?, .signInHostOffline?:
            return String(localized: "The connection service isn't reachable right now. Try again later.")
        default:
            return error.localizedDescription
        }
    }

    /// Il connettore è sparito o è cambiato mentre si collegava (404, 409 `connector_removed`): va riletta la lista.
    static func needsRefetch(_ error: any Error) -> Bool {
        switch error as? AriaError {
        case .http(404, _)?, .http(409, _)?: true
        default: false
        }
    }

    static var roleMessage: String {
        String(localized: "Your role isn't allowed to do this. Ask a company owner or admin.")
    }
}
