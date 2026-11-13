//
//  AdminRolesFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Cosa dire quando una chiamata di Roles & Rights è rifiutata: si legge `detail.code` (AriaAccessRefusal), mai il
//  `message` del server. Una sessione scaduta passa da `backend.handle`; una chiamata annullata non è un errore.
//

import Foundation

enum AdminRolesFailure {
    /// Di cosa parlava la chiamata: un 404 senza codice noto è un ruolo sparito o una persona non più membro.
    enum Subject { case role, person }

    static func message(for error: any Error, about subject: Subject, backend: AriaBackend) -> String? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        if AriaHTTP.isOffline(error) { return error.localizedDescription }
        switch error as? AriaError {
        case .signedOut?:
            backend.handle(error)
            return nil
        case .accessRefused(let refusal)?:
            return refusal.localized
        case .permissionDenied?:
            return String(localized: "Your role doesn't allow this. Ask your admin.")
        case .notOnPhone?:
            return error.localizedDescription
        case .http(404, _)?:
            return subject == .person ? String(localized: "This person is no longer a member of the company.")
                : AriaAccessRefusal.roleNotFound.localized
        default:
            return String(localized: "Something went wrong. Try again.")
        }
    }

    static func refusal(_ error: any Error) -> AriaAccessRefusal? {
        if case .accessRefused(let refusal)? = error as? AriaError { refusal } else { nil }
    }
}
