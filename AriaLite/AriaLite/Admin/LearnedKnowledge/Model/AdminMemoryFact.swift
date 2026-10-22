//
//  AdminMemoryFact.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un fatto imparato dall'azienda (MemoryFactView del backend, chiavi in camelCase). Lettura tollerante:
//  servono solo id e testo; stato, fiducia, autore e provenienza possono mancare o avere valori nuovi.
//  `AriaMemoryFact` della chat ha solo id, testo e stato: qui serve tutta la scheda.
//

import Foundation

nonisolated struct AdminMemoryFact: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    /// Il testo originale, quello che si modifica (mai la traduzione).
    let content: String
    let context: String?
    let category: String?
    /// Valore grezzo (`pending`, `approved`…), vedi AdminMemoryFactStatus.
    let status: String?
    /// 0…1.
    let confidence: Double?
    let decayedConfidence: Double?
    /// `auto_extracted` (dalla chat) o `manual` (scritto da una persona).
    let source: String?
    /// `fact`, `correction`, `reflection`.
    let kind: String?
    /// `verified`, `sme_confirmed`, `user_confirmed`, `unverified`.
    let trustLevel: String?
    let evidence: [String]
    /// Cosa dicono i documenti: `agree`, `contradict`, `novel`.
    let truthVerdict: String?
    let conflictingEvidence: String?
    /// Chi l'ha validato: un utente, oppure `system` per l'approvazione automatica.
    let validatedBy: String?
    let taskType: String?
    let hitCount: Int
    let helpCount: Int
    let missCount: Int
    let lastUsedAt: Date?
    /// `nil`: vale per tutta l'azienda.
    let plantId: String?
    /// Nome di chi l'ha proposto (testo libero).
    let creator: String?
    /// Id (o email) dell'utente che l'ha proposto.
    let createdBy: String?
    let approvedAt: Date?
    let sourceQuestion: String?
    let sourceAnswer: String?
    let sourceAnswerSummary: String?
    let sessionId: String?
    let createdAt: Date?
    let updatedAt: Date?

    var knownStatus: AdminMemoryFactStatus? { status.flatMap(AdminMemoryFactStatus.init(rawValue:)) }
    var isManual: Bool { source == "manual" }
    var isAutoValidated: Bool { validatedBy == "system" }

    private enum CodingKeys: String, CodingKey {
        case id, content, context, category, status, confidence, decayedConfidence, source, kind, trustLevel
        case evidence, truthVerdict, conflictingEvidence, validatedBy, taskType, hitCount, helpCount, missCount
        case lastUsedAt, plantId, creator, createdBy, approvedAt, sourceQuestion, sourceAnswer
        case sourceAnswerSummary, sessionId, createdAt, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            guard let value = try? c.decodeIfPresent(AriaFlexibleID.self, forKey: key)?.value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        func number(_ key: CodingKeys) -> Double? {
            if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
            return text(key).flatMap(Double.init)
        }
        func count(_ key: CodingKeys) -> Int { number(key).map { Int($0) } ?? 0 }
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }

        guard let id = text(.id), let content = text(.content) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: c.codingPath, debugDescription: "Fatto senza id o testo"))
        }
        self.id = id
        self.content = content
        context = text(.context)
        category = text(.category)
        status = text(.status)
        confidence = number(.confidence)
        decayedConfidence = number(.decayedConfidence)
        source = text(.source)
        kind = text(.kind)
        trustLevel = text(.trustLevel)
        evidence = ((try? c.decodeIfPresent(AriaLossyArray<String>.self, forKey: .evidence))?.items ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        truthVerdict = text(.truthVerdict)
        conflictingEvidence = text(.conflictingEvidence)
        validatedBy = text(.validatedBy)
        taskType = text(.taskType)
        hitCount = count(.hitCount)
        helpCount = count(.helpCount)
        missCount = count(.missCount)
        lastUsedAt = date(.lastUsedAt)
        plantId = text(.plantId)
        creator = text(.creator)
        createdBy = text(.createdBy)
        approvedAt = date(.approvedAt)
        sourceQuestion = text(.sourceQuestion)
        sourceAnswer = text(.sourceAnswer)
        sourceAnswerSummary = text(.sourceAnswerSummary)
        sessionId = text(.sessionId)
        createdAt = date(.createdAt)
        updatedAt = date(.updatedAt)
    }

    /// Chi l'ha proposto, come chiave per il filtro "Author": l'utente, altrimenti il nome scritto.
    var authorKey: String? { createdBy ?? creator }
}

/// GET …/memory-facts: `{facts, total}`. Si accetta anche un array semplice.
nonisolated struct AdminMemoryFactPage: Decodable, Sendable {
    let facts: [AdminMemoryFact]
    /// Quanti fatti ci sono in tutto con questo filtro (per "Load more").
    let total: Int?

    private enum CodingKeys: String, CodingKey { case facts, total }

    init(from decoder: any Decoder) throws {
        if let rows = try? decoder.singleValueContainer().decode(AriaLossyArray<AdminMemoryFact>.self) {
            facts = rows.items
            total = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        facts = (try c.decodeIfPresent(AriaLossyArray<AdminMemoryFact>.self, forKey: .facts))?.items ?? []
        total = try? c.decodeIfPresent(Int.self, forKey: .total)
    }
}
