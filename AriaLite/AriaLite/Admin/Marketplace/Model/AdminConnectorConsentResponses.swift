//
//  AdminConnectorConsentResponses.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Le risposte dei passi che portano al consenso di un connettore one-click: l'ispezione del server MCP
//  (oauth/inspect) e la chiusura del consenso Composio (composio/complete). Lettura tollerante: i campi
//  che non servono all'app non si leggono, e uno che manca o ha un tipo inatteso non rompe la risposta.
//

import Foundation

/// POST /connectors/oauth/inspect. Dell'intera risposta all'app serve una cosa sola.
nonisolated struct AdminConnectorInspect: Decodable, Sendable {
    /// `false`: il server non ha un progetto Composio per questo connettore, nessuno può abilitarlo.
    /// `nil`: il server non l'ha detto, si lascia decidere a lui al momento di abilitare.
    let platformClientAvailable: Bool?

    private enum CodingKeys: String, CodingKey { case platformClientAvailable }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        platformClientAvailable = try? c.decodeIfPresent(Bool.self, forKey: .platformClientAvailable)
    }
}

/// POST /connectors/composio/complete.
nonisolated struct AdminComposioCompletion: Decodable, Sendable {
    let provider: String?
    let displayName: String?
    /// L'account con cui l'utente ha acconsentito, quando Composio lo dice.
    let accountEmail: String?

    private enum CodingKeys: String, CodingKey { case provider, displayName, accountEmail }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            guard let value = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        provider = text(.provider)
        displayName = text(.displayName)
        accountEmail = text(.accountEmail)
    }
}
