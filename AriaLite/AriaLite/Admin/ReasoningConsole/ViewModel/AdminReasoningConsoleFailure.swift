//
//  AdminReasoningConsoleFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come la Reasoning console racconta un errore. Un 403 è un ruolo senza permesso: si dice e si resta
//  dentro; solo la sessione scaduta passa da `backend.handle`. Trace e attribution hanno i loro casi.
//

import Foundation

@MainActor
enum AdminReasoningConsoleFailure {
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
            return String(localized: "Not found. It may have been deleted.")
        default:
            return error.localizedDescription
        }
    }

    /// 404 `trace_not_found`: alcuni turni non scrivono mai la trace (chiamata diretta a un tool, scrittura
    /// fallita); un turno appena finito può non averla ancora.
    static func isMissingTrace(_ error: any Error) -> Bool {
        if case .http(let status, _)? = error as? AriaError { return status == 404 }
        return false
    }

    /// 409 `attribution_unavailable` (o 404, trace assente): definitivo, non si riprova.
    static func isUnavailable(_ error: any Error) -> Bool {
        if case .http(let status, _)? = error as? AriaError { return status == 409 || status == 404 }
        return false
    }

    /// Il motivo scritto dal server, se c'è (`detail.message`).
    static func serverDetail(_ error: any Error) -> String? {
        guard case .http(_, let detail)? = error as? AriaError else { return nil }
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var roleMessage: String {
        String(localized: "Your role isn't allowed to do this. Ask a company owner or admin.")
    }
}
