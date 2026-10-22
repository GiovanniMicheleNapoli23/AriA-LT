//
//  AdminKnowledgeGraphFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come il Knowledge Graph racconta un errore. Un 403 su una lista vuol dire che il ruolo non la vede:
//  quella parte del grafo manca, il resto si mostra. Solo la sessione scaduta passa da `backend.handle`.
//

import Foundation

@MainActor
enum AdminKnowledgeGraphFailure {
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
            return String(localized: "Not available on this server.")
        default:
            return error.localizedDescription
        }
    }

    static var roleMessage: String {
        String(localized: "Not available for your role.")
    }
}
