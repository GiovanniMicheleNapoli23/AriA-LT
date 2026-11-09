//
//  AdminScenarioReviewList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  GET …/session-reviews: il riepilogo, le sessioni e tre liste piatte di tutta l'azienda (feedback,
//  cose imparate, passi) legate alle sessioni da `sessionId` ed `episode`. Le divide il view model.
//

import Foundation

nonisolated struct AdminScenarioReviewList: Decodable, Sendable {
    let summary: AdminScenarioReviewSummary?
    private let sessionRows: AriaLossyArray<AdminScenarioSessionReview>?
    private let feedbackRows: AriaLossyArray<AdminScenarioFeedbackEvent>?
    private let learnedRows: AriaLossyArray<AdminScenarioLearned>?
    private let stepRows: AriaLossyArray<AdminScenarioStep>?

    private enum CodingKeys: String, CodingKey {
        case summary
        case sessionRows = "sessions"
        case feedbackRows = "feedback"
        case learnedRows = "learned"
        case stepRows = "steps"
    }

    var sessions: [AdminScenarioSessionReview] { sessionRows?.items ?? [] }
    var feedback: [AdminScenarioFeedbackEvent] { feedbackRows?.items ?? [] }
    var learned: [AdminScenarioLearned] { learnedRows?.items ?? [] }
    var steps: [AdminScenarioStep] { stepRows?.items ?? [] }
}

/// Il riepilogo delle sessioni elencate. `awaitingReview` è quello su cui agire.
nonisolated struct AdminScenarioReviewSummary: Decodable, Sendable {
    let sessions: Int?
    let reviewed: Int?
    let reviewedShare: Double?
    let awaitingReview: Int?
    let avgRating: Double?
    let reportedIssues: Int?
    let resolved: Int?
    let unresolved: Int?
    let unclear: Int?
}

/// Una cosa detta su una sessione (voto, segnalazione di un passo, revisione, nota dell'admin), così com'è.
nonisolated struct AdminScenarioFeedbackEvent: Decodable, Sendable, Identifiable {
    let id: String
    let sessionId: String
    let episode: Int?
    let sessionTitle: String?
    let kind: String?
    let vote: String?
    let action: String?
    let step: Int?
    let stepTitle: String?
    let stepLabel: String?
    let outcome: String?
    let rating: Int?
    let note: String?
    let answerExcerpt: String?
    let question: String?
    /// Valorizzato quando il feedback ha insegnato qualcosa ad Aria.
    let reflectionId: String?
    let createdBy: String?
    private let createdAtRaw: String?

    private enum CodingKeys: String, CodingKey {
        case id, sessionId, episode, sessionTitle, kind, vote, action, step, stepTitle, stepLabel, outcome, rating
        case note, answerExcerpt, question, reflectionId, createdBy
        case createdAtRaw = "createdAt"
    }

    var createdAt: Date? { AriaDate.parse(createdAtRaw) }
}

/// Qualcosa che Aria ha imparato da una sessione (un fatto o una riflessione da una correzione).
nonisolated struct AdminScenarioLearned: Decodable, Sendable, Identifiable {
    let factId: String
    let sessionId: String
    let content: String
    let kind: String?
    let status: String?

    var id: String { factId }
}

/// Un passo della sessione come lo elenca il report di chiusura.
nonisolated struct AdminScenarioStep: Decodable, Sendable {
    let sessionId: String
    let episode: Int?
    let label: String?
    let title: String?
    let kind: String?
    let outcome: String?
    let operatorReport: String?
    private let whenRaw: String?

    private enum CodingKeys: String, CodingKey {
        case sessionId, episode, label, title, kind, outcome, operatorReport
        case whenRaw = "when"
    }

    var when: Date? { AriaDate.parse(whenRaw) }
}
