//
//  AdminUserConfirmation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le conferme della scheda della persona (§5): cosa si sta per fare, il testo dell'avviso e la scelta del nuovo
//  ruolo quando un titolare scende di livello. Solo dati: i testi li compone AdminUserDetailViewModel.
//

import Foundation

/// Una conferma da chiedere prima di scrivere (interruttori, stato, sessioni).
nonisolated enum AdminUserConfirmation: Equatable, Identifiable, Sendable {
    case appOff
    case fieldOff
    case suspend
    case remove
    case endSession(AdminUserSession)
    case endAllSessions

    var id: String {
        switch self {
        case .appOff: "appOff"
        case .fieldOff: "fieldOff"
        case .suspend: "suspend"
        case .remove: "remove"
        case .endSession(let session): "end-\(session.id)"
        case .endAllSessions: "endAll"
        }
    }
}

/// Le conferme del livello (§5.2), sulla pagina del livello.
nonisolated enum AdminUserLevelConfirmation: Equatable, Identifiable, Sendable {
    /// "Make {name} an owner?": con il ruolo che perde, se ne ha uno.
    case promote(losingRole: String?)
    /// "Remove {name} as an owner?" dopo la scelta del nuovo ruolo (`nil`: nessun ruolo).
    case demote(roleId: String?)
    /// Azienda senza ruoli: "{name} will no longer be an owner."
    case legacyDemotion

    var id: String {
        switch self {
        case .promote: "promote"
        case .demote: "demote"
        case .legacyDemotion: "legacy"
        }
    }
}

/// Il foglio "Choose {name}'s new role": su se stessi il pulsante è "Step down" e manda subito.
nonisolated struct AdminUserDemotion: Equatable, Identifiable, Sendable {
    let id = UUID()
    let isSelf: Bool
}

/// Il testo di un avviso di conferma.
nonisolated struct AdminUserAlertContent: Equatable, Sendable {
    let title: String
    let message: String
    let confirmTitle: String
    var isDestructive = false
}
