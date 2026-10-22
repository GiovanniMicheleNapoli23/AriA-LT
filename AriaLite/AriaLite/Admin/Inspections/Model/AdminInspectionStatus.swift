//
//  AdminInspectionStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un'ispezione. L'OpenAPI dice solo `status: string`: i valori e i sinonimi qui sotto sono
//  IPOTESI da verificare dal vivo. Un valore che l'app non conosce resta com'è (etichetta = testo del server).
//

import Foundation

nonisolated enum AdminInspectionStatus: String, CaseIterable, Identifiable, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled

    var id: String { rawValue }

    /// Il valore grezzo del server (anche sinonimi: `done`, `scheduled`…) come stato noto.
    init?(raw: String?) {
        switch raw?.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") {
        case "pending", "scheduled", "open", "planned", "todo", "to_do", "new", "draft": self = .pending
        case "in_progress", "started", "active", "ongoing", "running": self = .inProgress
        case "completed", "complete", "done", "closed", "finished": self = .completed
        case "cancelled", "canceled": self = .cancelled
        default: return nil
        }
    }

    /// Completata o annullata: non c'è più niente da fare.
    var isClosed: Bool { self == .completed || self == .cancelled }

    var label: String { Self.label(for: rawValue) }

    var systemImage: String {
        switch self {
        case .pending: "clock"
        case .inProgress: "play.circle"
        case .completed: "checkmark.seal"
        case .cancelled: "xmark.circle"
        }
    }

    /// Etichetta di un valore grezzo: i noti tradotti, gli altri com'erano ("in_review" → "In review").
    static func label(for raw: String) -> String {
        switch Self(raw: raw) {
        case .pending?: String(localized: "Pending")
        case .inProgress?: String(localized: "In progress")
        case .completed?: String(localized: "Completed")
        case .cancelled?: String(localized: "Cancelled")
        case nil:
            raw.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces).capitalized
        }
    }
}
