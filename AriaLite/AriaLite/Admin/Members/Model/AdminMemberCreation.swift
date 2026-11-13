//
//  AdminMemberCreation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  I tipi della creazione di una persona: la qualifica scelta nel modulo, gli avvisi da mostrare nella scheda
//  appena aperta (la persona esiste già, non si torna indietro) e l'esito del salvataggio.
//

import Foundation

/// La qualifica (`role` di POST /v1/users): un elenco chiuso, non concede niente. Vuota: non si manda.
nonisolated enum AdminMemberLabel: String, CaseIterable, Identifiable, Sendable {
    case none = ""
    case technician
    case manager

    var id: String { rawValue }

    /// Il valore per il server; `nil` se la qualifica è vuota (non si manda `role` vuoto).
    var apiValue: String? { self == .none ? nil : rawValue }

    var title: String {
        switch self {
        case .none: String(localized: "None")
        case .technician: String(localized: "Technician")
        case .manager: String(localized: "Manager")
        }
    }
}

/// Cosa è successo dopo la creazione e va detto a chi l'ha fatta, in cima alla scheda della persona.
nonisolated enum AdminMemberCreationNotice: Equatable, Sendable {
    /// Con l'email c'era già un titolare o un admin: ruolo e stato non cambiano.
    case alreadyOwnerOrAdmin
    /// La persona è senza ruolo: va scelto (il selettore si apre).
    case noRoleChooseOne
    /// Era già in azienda con un altro ruolo: quello scelto è stato ignorato.
    case roleUnchanged
    /// "Può usare l'app" era acceso, ma titolari e admin entrano già nell'app.
    case appSkippedOwnerOrAdmin
    /// "Può usare l'app" era acceso, ma la persona è sospesa in azienda.
    case appSkippedSuspended
    /// La persona è creata, ma l'accesso all'app no: il motivo.
    case appNotGiven(String)
    /// L'accesso è dato, ma l'email d'invito non è partita.
    case emailNotSent
}

/// L'esito di una creazione riuscita.
nonisolated struct AdminMemberCreationResult: Equatable, Sendable {
    let userId: String
    let notices: [AdminMemberCreationNotice]
}
