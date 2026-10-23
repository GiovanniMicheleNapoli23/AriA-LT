//
//  AdminConnectorRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle scritture sui connettori. In camelCase: l'endpoint li scrive in snake_case.
//  I campi `nil` non partono (JSONEncoder salta gli opzionali vuoti).
//

import Foundation

/// PUT /connectors/maintainx: la chiave e, al secondo giro, l'organizzazione scelta.
nonisolated struct AdminConnectorMaintainXConnect: Encodable, Sendable {
    let apiKey: String
    let organizationId: String?
}

/// PUT /connectors/{provider}: server MCP con credenziale statica.
nonisolated struct AdminConnectorRemoteConnect: Encodable, Sendable {
    let mcpUrl: String
    /// `none`, `bearer` o `header`.
    let authMode: String
    let apiKey: String?
    let authHeaderName: String?
    let organizationId: String?
    let displayName: String?
}

/// POST /connectors/{provider}/oauth/start per una riga che esiste già: solo il permesso di scrittura.
nonisolated struct AdminConnectorOAuthStartRequest: Encodable, Sendable {
    let requestWrite: Bool
}

/// PUT /connectors/{provider}/register: abilita un connettore one-click. Per-membro: ognuno collega poi il suo account.
nonisolated struct AdminConnectorRegister: Encodable, Sendable {
    let mcpUrl: String
    /// Sempre `user` per un one-click.
    let connectionScope: String
    let displayName: String?
}

/// POST /connectors/oauth/inspect: il server MCP da interrogare.
nonisolated struct AdminConnectorInspectRequest: Encodable, Sendable {
    let mcpUrl: String
}

/// POST /connectors/composio/complete: il `session_uri` dell'URL su cui è finito il consenso.
nonisolated struct AdminComposioCompleteRequest: Encodable, Sendable {
    let sessionUri: String
}

/// Come un server con credenziale statica riceve la chiave.
nonisolated enum AdminConnectorAuthMode: String, Sendable, CaseIterable, Identifiable {
    case bearer, header, none

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bearer: String(localized: "Bearer token")
        case .header: String(localized: "Custom header")
        case .none: String(localized: "No authentication")
        }
    }

    /// Il testo di un `auth_mode` qualsiasi del server (anche `oauth`).
    static func label(for raw: String) -> String {
        if let mode = AdminConnectorAuthMode(rawValue: raw.lowercased()) { return mode.label }
        if raw.lowercased().contains("oauth") { return String(localized: "OAuth") }
        return raw
    }
}
