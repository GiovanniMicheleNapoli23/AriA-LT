//
//  AdminConnector.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un connettore dell'azienda (ConnectorView del backend): stato, server, autenticazione, organizzazione
//  e connessione personale. Lettura tollerante: serve solo `provider`, tutto il resto può mancare.
//  Mai la credenziale: il server manda al massimo le ultime cifre (`key_hint`).
//

import Foundation

nonisolated struct AdminConnector: Decodable, Sendable, Identifiable, Hashable {
    /// Lo slug della rotta (`maintainx`, `hubspot`, …): identifica il connettore nell'azienda.
    let provider: String
    /// Valore grezzo (`connected`, `error`, …): vedi AdminConnectorStatus.
    let status: String
    /// `builtin` (MaintainX) o `remote` (server MCP).
    let kind: String
    let mcpUrl: String?
    /// `bearer`, `header`, `none`, `oauth`…
    let authMode: String
    let grantedScopes: [String]
    let displayName: String?
    let toolCount: Int
    let lastDiscoveredAt: Date?
    let keyHint: String?
    let organizationId: String?
    /// Le organizzazioni fra cui scegliere quando la chiave ne vede più d'una.
    let organizations: [AdminConnectorOrganization]
    /// I database approvati (sola lettura sul telefono).
    let allowedInstances: [AdminConnectorInstance]
    let lastVerifiedAt: Date?
    let lastError: String?
    let updatedAt: Date?
    let updatedBy: String?
    /// `company` (una connessione per tutti) o `user` (ogni membro collega il suo account).
    let connectionScope: String
    let oauthClientId: String?
    let requiresClient: Bool
    let usesPlatformClient: Bool
    /// La connessione di chi guarda, per un connettore personale.
    let myGrant: AdminConnectorMyGrant?
    let memberCount: Int?

    var id: String { provider }

    var isMaintainX: Bool { provider == AdminConnector.maintainXProvider }
    var isPerMember: Bool { connectionScope == "user" }
    var knownStatus: AdminConnectorStatus { AdminConnectorStatus(raw: status) }

    /// OAuth: non c'è una chiave da incollare, si passa dal consenso nel browser.
    var usesOAuth: Bool {
        guard !isMaintainX else { return false }
        return authMode.lowercased().contains("oauth") || requiresClient || usesPlatformClient
            || oauthClientId != nil || isPerMember
    }

    /// Server con credenziale statica (bearer, header, nessuna): si aggiorna con PUT {provider}.
    var usesStaticCredential: Bool { !isMaintainX && !usesOAuth }

    var name: String { displayName ?? AdminConnector.prettyName(provider) }

    /// La riga sotto il nome nella griglia: tool esposti e connessione personale.
    var summaryLine: String {
        var parts: [String] = []
        if toolCount > 0 { parts.append(String(localized: "\(toolCount) tools")) }
        if isPerMember {
            parts.append(myGrant == nil ? String(localized: "Your account isn't connected")
                                        : String(localized: "Your account is connected"))
        } else if isMaintainX {
            parts.append(String(localized: "Built-in"))
        }
        return parts.joined(separator: " · ")
    }

    var organizationName: String? {
        guard let organizationId else { return nil }
        return organizations.first { $0.id == organizationId }?.name ?? organizationId
    }

    static let maintainXProvider = "maintainx"

    /// "google-drive" → "Google Drive"; i nomi noti con le maiuscole giuste.
    static func prettyName(_ provider: String) -> String {
        let known = ["maintainx": "MaintainX", "hubspot": "HubSpot", "erpipe": "ERPipe", "gmail": "Gmail",
                     "github": "GitHub", "sap": "SAP", "odoo": "Odoo"]
        if let name = known[provider.lowercased()] { return name }
        return provider.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Le chiavi arrivano già in camelCase (`.snakeCased()` sull'endpoint).
    private enum CodingKeys: String, CodingKey {
        case provider, status, kind, mcpUrl, authMode, grantedScopes, displayName, toolCount, lastDiscoveredAt
        case keyHint, organizationId, organizations, allowedInstances, lastVerifiedAt, lastError, updatedAt
        case updatedBy, connectionScope, oauthClientId, requiresClient, usesPlatformClient, myGrant, memberCount
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            guard let value = try? c.decodeIfPresent(AriaFlexibleID.self, forKey: key)?.value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }
        func flag(_ key: CodingKeys) -> Bool { (try? c.decodeIfPresent(Bool.self, forKey: key)) ?? false }

        guard let provider = text(.provider) else {
            throw DecodingError.keyNotFound(CodingKeys.provider,
                                            .init(codingPath: c.codingPath, debugDescription: "Connettore senza provider"))
        }
        self.provider = provider
        status = text(.status) ?? "unknown"
        kind = text(.kind) ?? "builtin"
        mcpUrl = text(.mcpUrl)
        authMode = text(.authMode) ?? "bearer"
        grantedScopes = (try? c.decodeIfPresent([String].self, forKey: .grantedScopes)) ?? []
        displayName = text(.displayName)
        toolCount = (try? c.decodeIfPresent(Int.self, forKey: .toolCount)) ?? 0
        lastDiscoveredAt = date(.lastDiscoveredAt)
        keyHint = text(.keyHint)
        organizationId = text(.organizationId)
        organizations = (try? c.decodeIfPresent(AriaLossyArray<AdminConnectorOrganization>.self, forKey: .organizations))?.items ?? []
        allowedInstances = (try? c.decodeIfPresent(AriaLossyArray<AdminConnectorInstance>.self, forKey: .allowedInstances))?.items ?? []
        lastVerifiedAt = date(.lastVerifiedAt)
        lastError = text(.lastError)
        updatedAt = date(.updatedAt)
        updatedBy = text(.updatedBy)
        connectionScope = text(.connectionScope) ?? "company"
        oauthClientId = text(.oauthClientId)
        requiresClient = flag(.requiresClient)
        usesPlatformClient = flag(.usesPlatformClient)
        myGrant = try? c.decodeIfPresent(AdminConnectorMyGrant.self, forKey: .myGrant)
        memberCount = try? c.decodeIfPresent(Int.self, forKey: .memberCount)
    }
}

/// Un'organizzazione su cui la chiave può agire (MaintainX), da scegliere.
nonisolated struct AdminConnectorOrganization: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
}

/// Un database su cui il connettore è approvato ad agire.
nonisolated struct AdminConnectorInstance: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    let label: String?
    let description: String?

    var title: String { (label?.isEmpty == false ? label : nil) ?? id }
}

/// La connessione personale di chi guarda (MyGrantView).
nonisolated struct AdminConnectorMyGrant: Decodable, Sendable, Hashable {
    let status: String
    let accountEmail: String?
    let connectedAt: Date?
    let lastError: String?

    private enum CodingKeys: String, CodingKey { case status, accountEmail, connectedAt, lastError }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "unknown"
        accountEmail = try? c.decodeIfPresent(String.self, forKey: .accountEmail)
        connectedAt = (try? c.decodeIfPresent(AriaWireDate.self, forKey: .connectedAt))?.value
        lastError = try? c.decodeIfPresent(String.self, forKey: .lastError)
    }
}

/// GET /connectors: `{ "connectors": [...] }`.
nonisolated struct AdminConnectorListResponse: Decodable, Sendable {
    let connectors: [AdminConnector]

    private enum CodingKeys: String, CodingKey { case connectors }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        connectors = (try? c.decodeIfPresent(AriaLossyArray<AdminConnector>.self, forKey: .connectors))?.items ?? []
    }
}
