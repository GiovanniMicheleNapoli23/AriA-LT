//
//  AdminUsersFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Cosa dire quando una chiamata della sezione Users fallisce (§8): si legge il codice (`detail.code`), mai il testo
//  del server. Ogni codice non elencato, un `detail` che non è un oggetto e un 422 di forma sono "Something went wrong".
//  Oltre al testo dice cosa fare: chiudere la sezione, tornare all'elenco, rileggere i diritti, lasciare l'azienda.
//

import Foundation

nonisolated struct AdminUsersFailure: Equatable, Sendable {
    let message: String
    /// Un 403 senza codice o `operation_forbidden`: sulla lettura dell'elenco la sezione si chiude (§2).
    var closesSection = false
    /// 404 (`not_found` o "Member not found"): la persona non c'è più, si torna all'elenco.
    var personGone = false
    /// `escalation_denied`, `permission_denied`: i diritti sono cambiati, si rilegge /v1/me.
    var reloadsRights = false
    /// 403 `session_ended`: questa sessione è chiusa per l'azienda, la si lascia.
    var sessionEnded = false
    /// 409 `user_limit_reached`: si rilegge il tetto, che lo spiega.
    var userLimitReached = false
    /// `role_not_found`: si rileggono i ruoli.
    var roleMissing = false

    static let generic = String(localized: "Something went wrong. Try again.")

    /// `nil` per una chiamata annullata o una sessione scaduta (quella la gestisce `backend.handle`).
    @MainActor
    static func from(_ error: any Error, backend: AriaBackend) -> Self? {
        if case .signedOut? = error as? AriaError { backend.handle(error) }
        return from(error)
    }

    /// La parte pura, per i test: `nil` per un annullamento o una sessione scaduta.
    static func from(_ error: any Error) -> Self? {
        if error is CancellationError { return nil }
        if let urlError = error as? URLError, urlError.code == .cancelled { return nil }
        guard let error = error as? AriaError else { return Self(message: generic) }
        switch error {
        case .signedOut, .locked:
            return nil
        case .peopleRefused(let refusal, _):
            switch refusal {
            case .ownerLimitReached, .ownerProtected, .roleRequired, .alreadyListed, .invalidEmail, .labelNotAllowed,
                 .alreadyInAnotherCompany:
                return Self(message: message(for: refusal))
            case .seatLimitReached:
                return Self(message: message(for: refusal))
            case .userLimitReached:
                return Self(message: message(for: refusal), userLimitReached: true)
            default:
                return Self(message: generic)
            }
        case .accessRefused(let refusal):
            switch refusal {
            case .escalationDenied:
                return Self(message: String(localized: "Your role doesn't allow this change."), reloadsRights: true)
            case .roleNotFound:
                return Self(message: String(localized: "That role no longer exists."), roleMissing: true)
            default:
                return Self(message: generic)
            }
        case .permissionDenied:
            return Self(message: String(localized: "Your role doesn't allow this."), reloadsRights: true)
        case .sessionEnded:
            return Self(message: String(localized: "Your session for this workspace was ended. Sign in again."),
                        sessionEnded: true)
        case .notOnPhone:
            return Self(message: generic, closesSection: true, reloadsRights: true)
        case .http(404, _):
            return Self(message: String(localized: "This person is no longer in the workspace."), personGone: true)
        case .http(403, _):
            return Self(message: generic, closesSection: true)
        default:
            return Self(message: generic)
        }
    }

    /// Le parole del §8 per i codici delle persone.
    static func message(for refusal: AriaPeopleRefusal) -> String {
        switch refusal {
        case .ownerLimitReached: String(localized: "This workspace already has 3 owners.")
        case .ownerProtected: String(localized: "The workspace needs at least one active owner.")
        case .roleRequired: String(localized: "Choose a role before removing an owner.")
        case .seatLimitReached:
            String(localized: "All the seats of your plan are in use. Upgrade to a bigger plan to add more people.")
        case .alreadyListed: String(localized: "This person is already in the workspace.")
        case .invalidEmail: String(localized: "Enter a valid email address.")
        case .labelNotAllowed: String(localized: "Choose technician or manager.")
        case .userLimitReached: String(localized: "You've reached the user limit")
        // Aggiungi e Riattiva (ARIA-121): un rifiuto normale, il modulo resta com'è per un altro indirizzo.
        case .alreadyInAnotherCompany:
            String(localized: "This person already belongs to another company. An email address can belong to one company only.")
        default: generic
        }
    }
}
