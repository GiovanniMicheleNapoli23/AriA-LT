//
//  AdminAppAccessState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Come sta l'accesso all'app di una persona (blocco "Accesso all'app" della scheda), cosa si può fare in
//  quello stato e il badge dell'elenco. Calcolati da AdminMemberRules, senza rete.
//

import Foundation

nonisolated enum AdminAppAccessState: Equatable, Sendable {
    /// Titolare o admin: entrano nell'app senza licenza.
    case ownerOrAdmin
    /// Sospesa in tutta l'azienda: la riga mobile dice sempre `suspended`, anche se era revocata, quindi lo stato
    /// dell'app non si conosce. `hasRow`: la riga mobile c'è.
    case companySuspended(hasRow: Bool)
    case none
    case invited(until: Date?)
    case expired(on: Date?)
    case active(availability: String)
    /// Solo l'app è sospesa (la persona è attiva in azienda).
    case appSuspended
}

nonisolated enum AdminAppAccessAction: Equatable, Sendable {
    /// POST …/mobile-users, poi l'email d'invito.
    case giveAccess
    /// Solo l'email d'invito (l'invito è ancora valido).
    case resendInvite
    /// …/resend per rinnovare l'invito scaduto, poi l'email.
    case renewAndResend
    case suspendApp
    case reactivateApp
    case revokeAccess
}

nonisolated struct AdminAppAccessOffer: Equatable, Sendable {
    let action: AdminAppAccessAction
    /// `false`: l'azione prenderebbe una licenza e le licenze sono finite.
    let isEnabled: Bool
}

/// Il badge di stato nell'elenco e nella testata (niente rosso: "sospeso" è grigio).
nonisolated enum AdminMemberBadgeKind: Equatable, Sendable {
    case companySuspended
    case appInvited
    case appInviteExpired
    case appSuspended
    case appActive
}

/// Lo stato dell'interruttore "Lavoro sul campo" nella scheda.
nonisolated enum AdminMemberFieldToggle: Equatable, Sendable {
    case enabled
    /// "Togli prima l'accesso all'app".
    case removeAppAccessFirst
    /// "Riattivala in azienda per cambiarlo".
    case reactivateFirst
    /// "Solo un admin può cambiarlo".
    case adminOnly
    case notAllowed
}

/// I ruoli fra cui chi guarda può scegliere per una persona.
nonisolated struct AdminMemberRoleChoice: Equatable, Sendable {
    let options: [AdminRole]
    /// Si offre "Nessun ruolo".
    let canUnassign: Bool
}
