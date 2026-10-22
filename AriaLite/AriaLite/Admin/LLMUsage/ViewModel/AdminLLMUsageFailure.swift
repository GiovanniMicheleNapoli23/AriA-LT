//
//  AdminLLMUsageFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Cosa dire quando una chiamata del consumo AI fallisce. Un 403 si spiega senza uscire dall'account;
//  solo una sessione scaduta passa da `backend.handle`.
//

import Foundation

enum AdminLLMUsageFailure {
    /// `nil` per una chiamata annullata (cambio di periodo, schermata chiusa): non è un errore da mostrare.
    static func message(for error: any Error, backend: AriaBackend) -> String? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
            return nil
        case .notOnPhone?, .http(403, _)?:
            return String(localized: "Your role doesn't have access to this. Ask an owner or admin of your company.")
        default:
            return error.localizedDescription
        }
    }
}
