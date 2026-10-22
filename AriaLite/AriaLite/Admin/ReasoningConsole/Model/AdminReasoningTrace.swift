//
//  AdminReasoningTrace.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La trace completa di un turno (TurnTraceView). Sono certi solo gli identificativi e la data:
//  nodi e fasi (percezione, retrieval, memoria, prompt, generazione, gate…) sono oggetti liberi (AriaJSON).
//

import Foundation

nonisolated struct AdminReasoningTrace: Decodable, Sendable {
    let responseId: String
    let sessionId: String?
    let episodeNumber: Int?
    let createdAt: String?
    /// I nodi del grafo eseguiti nel turno, in ordine.
    let nodes: [AriaJSON]
    /// Le fasi del turno per chiave del server (`scope`, `perception`, `retrieval`…), come arrivano.
    let phases: [String: AriaJSON]

    var created: Date? { AriaDate.parse(createdAt) }

    /// Le chiavi già lette a parte: tutto il resto è una fase.
    private static let known: Set<String> = ["responseId", "sessionId", "episodeNumber", "createdAt", "nodes"]

    init(from decoder: any Decoder) throws {
        let json = try AriaJSON(from: decoder)
        guard let object = json.objectValue, let responseId = object["responseId"]?.nonEmptyString else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "No responseId"))
        }
        self.responseId = responseId
        sessionId = object["sessionId"]?.nonEmptyString
        episodeNumber = object["episodeNumber"]?.doubleValue.map { Int($0) }
        createdAt = object["createdAt"]?.nonEmptyString
        nodes = object["nodes"]?.arrayValue ?? []
        phases = object.filter { !Self.known.contains($0.key) }
    }
}
