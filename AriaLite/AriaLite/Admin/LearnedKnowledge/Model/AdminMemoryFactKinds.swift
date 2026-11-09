//
//  AdminMemoryFactKinds.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I valori noti di stato, provenienza, tipo, affidabilità e verdetto di un fatto, con le etichette.
//  Un valore nuovo del backend non rompe niente: si mostra così com'è, leggibile.
//

import Foundation

/// Lo stato di un fatto. `conflict` è la quarantena: contraddice i documenti e aspetta un admin.
nonisolated enum AdminMemoryFactStatus: String, CaseIterable, Identifiable, Sendable {
    case pending, approved, rejected, conflict, contested, superseded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: String(localized: "To review")
        case .approved: String(localized: "Approved")
        case .rejected: String(localized: "Rejected")
        case .conflict: String(localized: "In conflict")
        case .contested: String(localized: "Contested")
        case .superseded: String(localized: "Superseded")
        }
    }

    var systemImage: String {
        switch self {
        case .pending: "clock"
        case .approved: "checkmark.seal"
        case .rejected: "xmark.octagon"
        case .conflict: "exclamationmark.triangle"
        case .contested: "questionmark.diamond"
        case .superseded: "arrow.uturn.forward"
        }
    }

    /// Si può approvare: tutto ciò che non è già approvato o sostituito da un fatto più nuovo.
    var canApprove: Bool { self != .approved && self != .superseded }
    /// Si può rifiutare: anche un fatto approvato (esce dai prompt).
    var canReject: Bool { self != .rejected && self != .superseded }

    static func label(for raw: String) -> String { Self(rawValue: raw)?.label ?? AdminMemoryFactLabels.readable(raw) }
}

nonisolated enum AdminMemoryFactLabels {
    static func source(_ raw: String) -> String {
        switch raw {
        case "manual": String(localized: "Written by a person")
        case "auto_extracted": String(localized: "Learned from chat")
        default: readable(raw)
        }
    }

    static func kind(_ raw: String) -> String {
        switch raw {
        case "fact": String(localized: "Fact")
        case "correction": String(localized: "Correction")
        case "reflection": String(localized: "Reflection")
        default: readable(raw)
        }
    }

    static func trust(_ raw: String) -> String {
        switch raw {
        case "verified": String(localized: "Verified")
        case "sme_confirmed": String(localized: "Confirmed by an expert")
        case "user_confirmed": String(localized: "Confirmed by a user")
        case "unverified": String(localized: "Unverified")
        default: readable(raw)
        }
    }

    static func verdict(_ raw: String) -> String {
        switch raw {
        case "agree": String(localized: "Agrees with documents")
        case "contradict": String(localized: "Contradicts documents")
        case "novel": String(localized: "Not in documents")
        default: readable(raw)
        }
    }

    /// `sme_confirmed` → "Sme confirmed": meglio di niente per un valore sconosciuto.
    static func readable(_ raw: String) -> String {
        let spaced = raw.replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}
