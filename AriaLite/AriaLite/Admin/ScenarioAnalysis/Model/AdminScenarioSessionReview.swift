//
//  AdminScenarioSessionReview.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sessione conclusa con il suo verdetto e chi l'ha dato (SessionReviewView). Una chat può avere più
//  procedure (`episode`): la riga è sessione + procedura, e ogni scrittura deve nominare la procedura.
//

import Foundation

nonisolated struct AdminScenarioSessionReview: Decodable, Sendable, Identifiable {
    let sessionId: String
    let episodeNumber: Int?
    let title: String?
    let alarmCode: String?
    let plantId: String?
    /// Il verdetto attuale (`resolved`, `unresolved`, `unclear`…).
    let verdict: String?
    /// Chi l'ha dato: Aria rileggendo la conversazione vale molto meno di una conferma umana.
    let verdictSource: String?
    let reviewOutcome: String?
    let reviewRating: Int?
    let reviewIssues: String?
    let reviewedBy: String?
    let stepFailures: Int?
    let stepConfusions: Int?
    let stepRevisions: Int?
    let stepCustomizations: Int?
    let answerUpvotes: Int?
    let answerDownvotes: Int?
    let forceClosed: Bool?
    let resolutionConfirmed: Bool?
    private let reviewedAtRaw: String?
    private let updatedAtRaw: String?
    private let startedAtRaw: String?

    private enum CodingKeys: String, CodingKey {
        case sessionId, title, alarmCode, plantId, verdict, verdictSource, reviewOutcome, reviewRating, reviewIssues
        case reviewedBy, stepFailures, stepConfusions, stepRevisions, stepCustomizations, answerUpvotes, answerDownvotes
        case forceClosed, resolutionConfirmed
        case episodeNumber = "episode"
        case reviewedAtRaw = "reviewedAt"
        case updatedAtRaw = "updatedAt"
        case startedAtRaw = "startedAt"
    }

    /// La procedura della chat (da 1).
    var episode: Int { episodeNumber ?? 1 }
    var id: String { "\(sessionId)#\(episode)" }

    var reviewedAt: Date? { AriaDate.parse(reviewedAtRaw) }
    var updatedAt: Date? { AriaDate.parse(updatedAtRaw) }
    var startedAt: Date? { AriaDate.parse(startedAtRaw) }

    /// Rivista da una persona: il verdetto non si regge più solo sulla lettura di Aria.
    var isReviewed: Bool { reviewOutcome != nil || reviewedAtRaw != nil }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return alarmCode ?? String(localized: "Untitled session")
    }

    var searchableFields: [String] {
        [title, alarmCode, verdict, reviewIssues, reviewedBy].compactMap(\.self)
    }
}
