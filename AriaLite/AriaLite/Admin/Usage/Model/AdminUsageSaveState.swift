//
//  AdminUsageSaveState.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Come una scheda che salva da sola dice come è andata l'ultima modifica ("Saving…", "Saved", "Not saved") e il
//  messaggio passeggero dopo un salvataggio del limite ("Spending limit saved").
//

import Foundation

nonisolated enum AdminUsageSaveState: Sendable, Equatable {
    case idle
    case saving
    /// "Saved", per un momento.
    case saved
    /// "Not saved" con "Retry": riprovare può servire.
    case error
    /// "Not saved" senza "Retry": prima va corretto un valore sulla scheda (una soglia non valida).
    case blocked

    /// "Saving…", "Saved" o "Not saved"; `nil` da fermo.
    var text: String? {
        switch self {
        case .idle: nil
        case .saving: String(localized: "usage.autosave.saving", defaultValue: "Saving…")
        case .saved: String(localized: "usage.autosave.saved", defaultValue: "Saved")
        case .error, .blocked: String(localized: "usage.autosave.notSaved", defaultValue: "Not saved")
        }
    }
}

/// Il messaggio che compare per qualche secondo dopo aver salvato o tolto il limite.
nonisolated struct AdminUsageBillingToast: Sendable, Equatable {
    var text: String
    /// Cambia a ogni messaggio: lo stesso testo due volte di fila si annuncia due volte.
    var id: Int
}
