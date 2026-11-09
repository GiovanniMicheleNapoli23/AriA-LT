//
//  AdminConnectorDetails.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Quello che si legge nel dettaglio di un connettore oltre alla sua riga: i tool esposti
//  (raggruppati per cosa ne fa ARIA), le connessioni dei membri e l'URL del consenso OAuth.
//

import Foundation

/// GET {provider}/tools: i tool del server divisi in "eseguiti", "chiedono conferma", "non disponibili".
nonisolated struct AdminConnectorTools: Decodable, Sendable {
    /// `discovered` (dall'ultima scoperta), `reviewed` (lista rivista), `unreviewed`.
    let source: String?
    let mcpUrl: String?
    let discoveredAt: Date?
    let toolCount: Int
    let runs: [AdminConnectorTool]
    let asks: [AdminConnectorTool]
    let unavailable: [AdminConnectorTool]

    var isEmpty: Bool { runs.isEmpty && asks.isEmpty && unavailable.isEmpty }

    private enum CodingKeys: String, CodingKey { case source, mcpUrl, discoveredAt, toolCount, runs, asks, unavailable }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func tools(_ key: CodingKeys) -> [AdminConnectorTool] {
            (try? c.decodeIfPresent(AriaLossyArray<AdminConnectorTool>.self, forKey: key))?.items ?? []
        }
        source = try? c.decodeIfPresent(String.self, forKey: .source)
        mcpUrl = try? c.decodeIfPresent(String.self, forKey: .mcpUrl)
        discoveredAt = (try? c.decodeIfPresent(AriaWireDate.self, forKey: .discoveredAt))?.value
        runs = tools(.runs)
        asks = tools(.asks)
        unavailable = tools(.unavailable)
        toolCount = (try? c.decodeIfPresent(Int.self, forKey: .toolCount)) ?? (runs.count + asks.count + unavailable.count)
    }
}

nonisolated struct AdminConnectorTool: Decodable, Sendable, Hashable, Identifiable {
    let name: String
    let description: String?
    /// Il tool modifica o cancella dati nel sistema collegato.
    let destructive: Bool

    var id: String { name }

    private enum CodingKeys: String, CodingKey { case name, description, destructive }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        let text = (try? c.decodeIfPresent(String.self, forKey: .description))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        description = text?.isEmpty == false ? text : nil
        destructive = (try? c.decodeIfPresent(Bool.self, forKey: .destructive)) ?? false
    }
}

/// I tre gruppi dei tool, nell'ordine della pagina web.
nonisolated enum AdminConnectorToolGroup: String, Sendable, CaseIterable, Identifiable {
    case runs, asks, unavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runs: String(localized: "Runs on its own")
        case .asks: String(localized: "Asks before running")
        case .unavailable: String(localized: "Not available")
        }
    }

    var systemImage: String {
        switch self {
        case .runs: "bolt.fill"
        case .asks: "hand.raised.fill"
        case .unavailable: "nosign"
        }
    }
}

/// GET {provider}/grants: `{ "grants": [...] }`.
nonisolated struct AdminConnectorGrantList: Decodable, Sendable {
    let grants: [AdminConnectorGrant]

    private enum CodingKeys: String, CodingKey { case grants }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grants = (try? c.decodeIfPresent(AriaLossyArray<AdminConnectorGrant>.self, forKey: .grants))?.items ?? []
    }
}

/// La connessione di un membro a un connettore personale, come la vede un owner/admin.
nonisolated struct AdminConnectorGrant: Decodable, Sendable, Hashable, Identifiable {
    let userId: String
    let accountEmail: String?
    let status: String
    let connectedAt: Date?
    let lastError: String?

    var id: String { userId }
    var title: String { accountEmail ?? userId }

    private enum CodingKeys: String, CodingKey { case userId, accountEmail, status, connectedAt, lastError }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(AriaFlexibleID.self, forKey: .userId).value
        accountEmail = try? c.decodeIfPresent(String.self, forKey: .accountEmail)
        status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "unknown"
        connectedAt = (try? c.decodeIfPresent(AriaWireDate.self, forKey: .connectedAt))?.value
        lastError = try? c.decodeIfPresent(String.self, forKey: .lastError)
    }
}

/// POST oauth/start e me/oauth/start: dove mandare il browser per il consenso.
nonisolated struct AdminConnectorOAuthStart: Decodable, Sendable {
    let authorizeUrl: String
    let expiresIn: Int?
    let scopes: [String]?
}
