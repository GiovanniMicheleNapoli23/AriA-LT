//
//  AriaBiometrics.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Face ID, Touch ID o il codice del telefono per aprire l'app con una sessione salvata.
//

import Foundation
import LocalAuthentication

/// Face ID (o Touch ID, o il codice del telefono) per aprire l'app con una sessione salvata.
nonisolated enum AriaBiometrics {
    /// Il telefono ha un codice: la sessione si può proteggere e l'app chiudere a chiave.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Il metodo che il sistema proporrà per primo (per il testo e l'icona del pulsante).
    static var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// Chiede Face ID (con il codice del telefono come riserva). Il contesto restituito
    /// apre i valori protetti del Keychain senza un secondo prompt.
    static func authenticate(reason: String) async throws -> LAContext {
        let context = LAContext()
        context.localizedFallbackTitle = String(localized: "Use Passcode")
        AriaAuthTrace.step("faceid.prompt")
        try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        AriaAuthTrace.step("faceid.done")
        return context
    }

    /// L'utente ha annullato (o il sistema ha interrotto il prompt): non è un errore da mostrare.
    static func isCancellation(_ error: any Error) -> Bool {
        guard let error = error as? LAError else { return false }
        return [.userCancel, .appCancel, .systemCancel, .notInteractive].contains(error.code)
    }
}
