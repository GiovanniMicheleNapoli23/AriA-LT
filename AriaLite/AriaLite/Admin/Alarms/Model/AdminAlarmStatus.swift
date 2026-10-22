//
//  AdminAlarmStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli stati di un allarme (EntityStatus dell'OpenAPI): il filtro dell'elenco, il badge e il modulo.
//  Un valore che il server aggiungesse in futuro si mostra com'è (vedi AdminAlarm.statusLabel).
//

import Foundation

nonisolated enum AdminAlarmStatus: String, CaseIterable, Identifiable, Sendable {
    case approved, draft, staged, rejected, superseded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .approved: String(localized: "Approved")
        case .draft: String(localized: "Draft")
        case .staged: String(localized: "Staged")
        case .rejected: String(localized: "Rejected")
        case .superseded: String(localized: "Superseded")
        }
    }

    var systemImage: String {
        switch self {
        case .approved: "checkmark.seal"
        case .draft: "pencil.line"
        case .staged: "tray.and.arrow.down"
        case .rejected: "xmark.octagon"
        case .superseded: "arrow.triangle.2.circlepath"
        }
    }

    /// Bozze in attesa di revisione: sono le uniche che si approvano in blocco.
    var isPending: Bool { self == .draft || self == .staged }
}
