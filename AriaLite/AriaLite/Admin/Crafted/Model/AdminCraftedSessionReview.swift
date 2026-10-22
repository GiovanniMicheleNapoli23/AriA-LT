//
//  AdminCraftedSessionReview.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le sessioni concluse di GET …/session-reviews (camelCase sul filo): verdetto e da chi viene,
//  il riepilogo, i passi della procedura e quello che Aria ne ha imparato. Tutto tollerante.
//

import Foundation

nonisolated struct AdminCraftedSessionReviews: Decodable, Sendable {
    let summary: AdminCraftedSessionSummary?
    let sessions: AriaLossyArray<AdminCraftedSessionReview>?
    let learned: AriaLossyArray<AdminCraftedLearned>?
    let steps: AriaLossyArray<AdminCraftedSessionStep>?

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try? c.decodeIfPresent(AdminCraftedSessionSummary.self, forKey: .summary)
        sessions = try? c.decodeIfPresent(AriaLossyArray<AdminCraftedSessionReview>.self, forKey: .sessions)
        learned = try? c.decodeIfPresent(AriaLossyArray<AdminCraftedLearned>.self, forKey: .learned)
        steps = try? c.decodeIfPresent(AriaLossyArray<AdminCraftedSessionStep>.self, forKey: .steps)
    }

    enum CodingKeys: String, CodingKey { case summary, sessions, learned, steps }
}

nonisolated struct AdminCraftedSessionSummary: Decodable, Sendable, Hashable {
    let sessions: Int?
    let reviewed: Int?
    let awaitingReview: Int?
    let avgRating: Double?
    let resolved: Int?
    let unresolved: Int?
}

/// Una procedura conclusa: la stessa chat può averne più d'una (`episode`).
nonisolated struct AdminCraftedSessionReview: Decodable, Sendable, Hashable, Identifiable {
    let sessionId: String
    let episode: Int?
    var title: String?
    let alarmCode: String?
    let plantId: String?
    let verdict: String?
    /// Chi ha deciso il verdetto: Aria rileggendo la chat o l'operatore. Pesano in modo diverso.
    let verdictSource: String?
    let reviewOutcome: String?
    let reviewRating: Int?
    let reviewIssues: String?
    let reviewedAt: String?
    let stepFailures: Int?
    let answerUpvotes: Int?
    let answerDownvotes: Int?
    let forceClosed: Bool?
    let resolutionConfirmed: Bool?
    let updatedAt: String?
    let startedAt: String?

    var id: String { "\(sessionId)#\(episode ?? 1)" }

    var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? String(localized: "Untitled session") : trimmed
    }

    /// La data più significativa: ultima modifica, altrimenti l'inizio.
    var date: Date? { AriaDate.parse(updatedAt ?? startedAt) }

    /// La stessa sessione con il titolo nuovo (dopo una rinomina).
    func withTitle(_ title: String) -> Self {
        var copy = self
        copy.title = title
        return copy
    }
}

/// Qualcosa che Aria ha imparato da una sessione (fatto o riflessione nata da una correzione).
nonisolated struct AdminCraftedLearned: Decodable, Sendable, Hashable, Identifiable {
    let factId: String
    let sessionId: String
    let content: String
    let kind: String?
    let status: String?

    var id: String { factId }
}

/// Un passo della procedura, come lo elenca il report di chiusura.
nonisolated struct AdminCraftedSessionStep: Decodable, Sendable, Hashable {
    let sessionId: String
    let episode: Int?
    let label: String?
    let title: String?
    let kind: String?
    let outcome: String?
    let operatorReport: String?
}
