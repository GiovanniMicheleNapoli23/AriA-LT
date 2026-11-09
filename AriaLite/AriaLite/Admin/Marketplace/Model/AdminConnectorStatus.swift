//
//  AdminConnectorStatus.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Lo stato di un connettore letto dal valore grezzo del server, in quattro famiglie (collegato,
//  da sistemare, in attesa, non collegato). Un valore nuovo del backend non rompe niente: diventa
//  "non collegato" con il suo testo.
//

import SwiftUI

nonisolated enum AdminConnectorStatus: Sendable, Hashable {
    case connected
    case attention
    case pending
    case disconnected

    init(raw: String) {
        let value = raw.lowercased()
        if ["connected", "active", "ok", "healthy", "verified", "ready"].contains(value) {
            self = .connected
        } else if ["error", "failed", "invalid", "expired", "revoked", "unauthorized", "unreachable", "degraded"]
                    .contains(where: value.contains) || value.hasPrefix("needs") {
            self = .attention
        } else if ["pending", "connecting", "awaiting", "in_progress"].contains(where: value.contains) {
            self = .pending
        } else {
            self = .disconnected
        }
    }

    var systemImage: String {
        switch self {
        case .connected: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .pending: "clock.fill"
        case .disconnected: "circle.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .connected: .green
        case .attention: .orange
        case .pending: .blue
        case .disconnected: .secondary
        }
    }

    /// Il testo dello stato; per i valori che non si riconoscono, quello del server ripulito.
    static func label(for raw: String) -> String {
        switch raw.lowercased() {
        case "connected", "active", "ok", "healthy", "verified", "ready": String(localized: "Connected")
        case "not_connected", "disconnected", "not_configured", "unconfigured", "none", "unknown", "":
            String(localized: "Not connected")
        case "error", "failed": String(localized: "Error")
        case "expired": String(localized: "Expired")
        case "revoked": String(localized: "Revoked")
        case "pending", "connecting": String(localized: "Pending")
        default: raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
