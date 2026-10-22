//
//  AdminMobileUserStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Stato di un operatore (invitato, scaduto, attivo, sospeso, revocato) e sua disponibilità (libero,
//  occupato, fuori turno): i valori del backend, con etichetta, icona e cosa si può fare in quello stato.
//

import Foundation

nonisolated enum AdminMobileUserStatus: String, CaseIterable, Sendable, Hashable {
    case active, invited, expired, suspended, revoked

    var label: String {
        switch self {
        case .active: String(localized: "Active")
        case .invited: String(localized: "Invited")
        case .expired: String(localized: "Invite expired")
        case .suspended: String(localized: "Suspended")
        case .revoked: String(localized: "Revoked")
        }
    }

    var systemImage: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .invited: "envelope.badge"
        case .expired: "clock.badge.exclamationmark"
        case .suspended: "pause.circle.fill"
        case .revoked: "xmark.circle.fill"
        }
    }

    /// Il link di accesso si può rimandare solo a chi non è ancora entrato.
    var canResend: Bool { self == .invited || self == .expired }
    /// Si sospende chi è attivo e si riattiva chi è sospeso (il PATCH accetta solo questi due).
    var canSuspend: Bool { self == .active }
    var canReactivate: Bool { self == .suspended }
    /// Solo chi è entrato (o lo è stato) ha dei telefoni collegati.
    var hasSessions: Bool { self == .active || self == .suspended }

    static func label(for raw: String) -> String {
        AdminMobileUserStatus(rawValue: raw)?.label ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

nonisolated enum AdminMobileUserAvailability: String, Sendable, Hashable {
    case available, busy
    case offDuty = "off_duty"

    var label: String {
        switch self {
        case .available: String(localized: "Available")
        case .busy: String(localized: "Busy")
        case .offDuty: String(localized: "Off duty")
        }
    }

    var systemImage: String {
        switch self {
        case .available: "circle.fill"
        case .busy: "circle.lefthalf.filled"
        case .offDuty: "moon.zzz.fill"
        }
    }

    static func label(for raw: String) -> String {
        AdminMobileUserAvailability(rawValue: raw)?.label ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
