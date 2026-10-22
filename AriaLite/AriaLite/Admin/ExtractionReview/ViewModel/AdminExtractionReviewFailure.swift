//
//  AdminExtractionReviewFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come la revisione delle estrazioni racconta un errore. Un 403 è un ruolo senza permesso (es. member
//  su un'approvazione): si dice chiaramente e si resta dentro. Solo la sessione scaduta passa da `backend.handle`.
//

import Foundation

@MainActor
enum AdminExtractionReviewFailure {
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
            return String(localized: "Not found. It may have been deleted or already reviewed.")
        default:
            return error.localizedDescription
        }
    }

    /// Il server non conosce la rotta o il body (bulk-approve): si ripiega sulle PATCH una per una.
    static func isUnsupported(_ error: any Error) -> Bool {
        guard case .http(let status, _)? = error as? AriaError else { return false }
        return [400, 404, 405, 422].contains(status)
    }

    static var roleMessage: String {
        String(localized: "Your role isn't allowed to do this. Ask a company owner or admin.")
    }
}
