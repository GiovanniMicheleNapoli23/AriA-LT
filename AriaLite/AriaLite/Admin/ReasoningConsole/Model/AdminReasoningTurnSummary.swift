//
//  AdminReasoningTurnSummary.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga della timeline dei turni di una sessione (TurnTraceSummary): domanda, tempi, nodi e
//  grounding. Niente testo del prompt: quello sta nella trace completa (AdminReasoningTrace).
//

import Foundation

nonisolated struct AdminReasoningTurnSummary: Decodable, Sendable, Hashable, Identifiable {
    let responseId: String
    let sessionId: String?
    let episodeNumber: Int?
    let createdAt: String?
    /// Dall'inizio alla fine del turno; `busyMs` il tempo di lavoro vero, `nodeWorkMs` la somma dei nodi.
    let durationMs: Int?
    let elapsedMs: Int?
    let busyMs: Int?
    let nodeWorkMs: Int?
    let question: String?
    let candidateCount: Int?
    let contextVoided: Bool?
    let groundingScore: Double?
    let groundingRecommendation: String?
    let ungroundedCount: Int?
    let hasAgentNode: Bool?
    let nodeCount: Int?
    let agent: String?
    let confidence: Double?

    var id: String { responseId }
    var created: Date? { AriaDate.parse(createdAt) }

    enum CodingKeys: String, CodingKey {
        case responseId, sessionId, episodeNumber, createdAt, durationMs, elapsedMs, busyMs, nodeWorkMs, question,
             candidateCount, contextVoided, groundingScore, groundingRecommendation, ungroundedCount,
             hasAgentNode, nodeCount, agent, confidence
    }

    /// Tollerante: solo `responseId` è indispensabile, il resto può mancare o cambiare tipo.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        responseId = try c.decode(String.self, forKey: .responseId)
        sessionId = try? c.decodeIfPresent(String.self, forKey: .sessionId)
        episodeNumber = try? c.decodeIfPresent(Int.self, forKey: .episodeNumber)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        durationMs = try? c.decodeIfPresent(Int.self, forKey: .durationMs)
        elapsedMs = try? c.decodeIfPresent(Int.self, forKey: .elapsedMs)
        busyMs = try? c.decodeIfPresent(Int.self, forKey: .busyMs)
        nodeWorkMs = try? c.decodeIfPresent(Int.self, forKey: .nodeWorkMs)
        question = try? c.decodeIfPresent(String.self, forKey: .question)
        candidateCount = try? c.decodeIfPresent(Int.self, forKey: .candidateCount)
        contextVoided = try? c.decodeIfPresent(Bool.self, forKey: .contextVoided)
        groundingScore = try? c.decodeIfPresent(Double.self, forKey: .groundingScore)
        groundingRecommendation = try? c.decodeIfPresent(String.self, forKey: .groundingRecommendation)
        ungroundedCount = try? c.decodeIfPresent(Int.self, forKey: .ungroundedCount)
        hasAgentNode = try? c.decodeIfPresent(Bool.self, forKey: .hasAgentNode)
        nodeCount = try? c.decodeIfPresent(Int.self, forKey: .nodeCount)
        agent = try? c.decodeIfPresent(String.self, forKey: .agent)
        confidence = try? c.decodeIfPresent(Double.self, forKey: .confidence)
    }
}

/// GET …/turn-traces. `hasMore` dice che ce ne sono altri, ma la rotta non ha offset: si mostrano i più recenti.
nonisolated struct AdminReasoningTurnList: Decodable, Sendable {
    let traces: [AdminReasoningTurnSummary]
    let total: Int?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey { case traces, total, hasMore }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        traces = (try? c.decodeIfPresent(AriaLossyArray<AdminReasoningTurnSummary>.self, forKey: .traces))?.items ?? []
        total = try? c.decodeIfPresent(Int.self, forKey: .total)
        hasMore = (try? c.decodeIfPresent(Bool.self, forKey: .hasMore)) ?? false
    }
}
