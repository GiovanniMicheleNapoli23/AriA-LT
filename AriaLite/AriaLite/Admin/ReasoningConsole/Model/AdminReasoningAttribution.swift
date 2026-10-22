//
//  AdminReasoningAttribution.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'attribution di una risposta (AttributionView): per ogni frase, il blocco del prompt a cui
//  somiglia di più. "Più vicino", non "derivato da": il server misura una somiglianza (coseno).
//

import Foundation

nonisolated struct AdminReasoningAttribution: Decodable, Sendable {
    let responseId: String?
    /// Cosa si è misurato (di solito `embedding-cosine`).
    let method: String?
    /// Sotto questa somiglianza la frase è `unsupported`.
    let floor: Double?
    let sentences: [AdminReasoningSentence]
    let spans: [AdminReasoningSpan]
    let summary: AdminReasoningAttributionSummary?

    enum CodingKeys: String, CodingKey { case responseId, method, floor, sentences, spans, summary }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        responseId = try? c.decodeIfPresent(String.self, forKey: .responseId)
        method = try? c.decodeIfPresent(String.self, forKey: .method)
        floor = try? c.decodeIfPresent(Double.self, forKey: .floor)
        sentences = (try? c.decodeIfPresent(AriaLossyArray<AdminReasoningSentence>.self, forKey: .sentences))?.items ?? []
        spans = (try? c.decodeIfPresent(AriaLossyArray<AdminReasoningSpan>.self, forKey: .spans))?.items ?? []
        summary = try? c.decodeIfPresent(AdminReasoningAttributionSummary.self, forKey: .summary)
    }
}

/// Una frase della risposta e il blocco del prompt più vicino. `kind == "unsupported"`: niente sopra la soglia,
/// `spanIndex` è nil ma `score` resta (la somiglianza migliore misurata).
nonisolated struct AdminReasoningSentence: Decodable, Sendable, Identifiable {
    let index: Int
    let text: String
    let kind: String?
    let spanIndex: Int?
    let score: Double?
    let label: String?

    var id: Int { index }
    var isUnsupported: Bool { kind == "unsupported" }
}

/// Un blocco di fonte del prompt mostrato al modello (documento, fatto, memoria…), con le frasi che ci cadono.
nonisolated struct AdminReasoningSpan: Decodable, Sendable, Identifiable {
    let index: Int
    let kind: String?
    let slot: String?
    let label: String?
    let hits: Int?
    let truncated: Bool?

    var id: Int { index }
}

nonisolated struct AdminReasoningAttributionSummary: Decodable, Sendable {
    let total: Int?
    let sourced: Int?
    let unsupported: Int?
    let byKind: [String: Int]?
}
