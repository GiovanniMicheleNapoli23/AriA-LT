//
//  AdminLLMUsageSession.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sessione di chat con il suo consumo (GET /v1/chat/sessions, POST .../stop). Senza id non si può
//  fermare né mostrare: la riga si salta. Lo stato è una stringa libera del server.
//

import Foundation

nonisolated struct AdminLLMUsageSession: Decodable, Sendable, Equatable, Identifiable {
    let id: String
    let title: String?
    let status: String
    let provider: String?
    let model: String?
    let startedAt: Date?
    let endedAt: Date?
    let lastActivityAt: Date?
    let durationS: Double?
    let totals: AdminLLMUsageTotals

    /// Stati che vogliono dire "ancora in corso": solo per loro compare Stop.
    var isActive: Bool {
        ["active", "running", "queued"].contains(status.lowercased())
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "active"
        provider = try c.decodeIfPresent(String.self, forKey: .provider)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        lastActivityAt = try c.decodeIfPresent(Date.self, forKey: .lastActivityAt)
        durationS = try c.decodeIfPresent(Double.self, forKey: .durationS)
        totals = try c.decodeIfPresent(AdminLLMUsageTotals.self, forKey: .totals) ?? .empty
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, status, provider, model, startedAt, endedAt, lastActivityAt, durationS, totals
    }
}
