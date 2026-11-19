//
//  AdminUsageFailure.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Cosa fare quando una chiamata della sezione Usage fallisce (contratto 7). Parte pura e testabile: si classifica
//  l'errore, poi il view model agisce. Nessun testo del server: la pagina dice "Usage figures are unavailable right now".
//

import Foundation

nonisolated enum AdminUsageFailure: Sendable, Equatable {
    /// Una chiamata annullata (cambio di ciclo, schermata chiusa): non è un errore da mostrare.
    case cancelled
    /// La sessione è scaduta: `backend.handle`.
    case signedOut
    /// 403 `session_ended`: un titolare ha chiuso questa sessione per l'azienda; si lascia l'azienda.
    case sessionEnded
    /// 403 `operation_forbidden`: la sessione non può usare la sezione. Si chiude.
    case sectionClosed
    /// 403 di una chiamata riservata ai titolari ("Insufficient role", `permission_denied`): si nascondono le parti da
    /// titolare e si rilegge la config.
    case ownerRefused
    /// Qualsiasi altro errore (503, rete, 422 di forma): niente cifre e "Riprova".
    case failed

    /// `ownerCall`: la chiamata è riservata ai titolari (notice-recipients, tetto, avvisi). Per le altre un 403 senza
    /// codice è un errore come gli altri: i diritti li rilegge `AriaBackend` da solo.
    static func classify(_ error: any Error, ownerCall: Bool = false) -> AdminUsageFailure {
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError, urlError.code == .cancelled { return .cancelled }
        guard let error = error as? AriaError else { return .failed }
        switch error {
        case .signedOut: return .signedOut
        // Sessione ancora chiusa da Face ID: la schermata di sblocco è già davanti, niente da mostrare né da fare.
        case .locked: return .cancelled
        case .sessionEnded: return .sessionEnded
        case .notOnPhone: return .sectionClosed
        case .permissionDenied, .http(403, _): return ownerCall ? .ownerRefused : .failed
        default: return .failed
        }
    }
}
