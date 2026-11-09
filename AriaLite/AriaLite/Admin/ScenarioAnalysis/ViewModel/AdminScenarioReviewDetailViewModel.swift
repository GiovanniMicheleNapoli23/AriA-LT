//
//  AdminScenarioReviewDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di una procedura rivista: verdetto e fonte, segnali, passi, traccia del feedback e cose
//  imparate. Legge la riga dalla lista (così una correzione si vede subito) e prepara i form e il report.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioReviewDetailViewModel {
    let reviews: AdminScenarioReviewsViewModel
    let report: AdminScenarioReportViewModel
    private let snapshot: AdminScenarioSessionReview

    init(reviews: AdminScenarioReviewsViewModel, snapshot: AdminScenarioSessionReview) {
        self.reviews = reviews
        self.snapshot = snapshot
        report = AdminScenarioReportViewModel(backend: reviews.backend, sessionId: snapshot.sessionId,
                                              episode: snapshot.episode, title: snapshot.title)
    }

    /// La riga aggiornata della lista, o quella aperta se nel frattempo è uscita dalla lista.
    var review: AdminScenarioSessionReview { reviews.session(id: snapshot.id) ?? snapshot }

    var feedback: [AdminScenarioFeedbackEvent] { reviews.feedback(for: review) }
    var steps: [AdminScenarioStep] { reviews.steps(for: review) }
    var learned: [AdminScenarioLearned] { reviews.learned(for: review) }

    /// "Procedure 2" quando la chat ne ha avute più d'una.
    var episodeLabel: String? {
        let episode = review.episode
        return episode > 1 ? String(localized: "Procedure \(episode)") : nil
    }

    var verdictLabel: String { review.verdict.map(AdminScenarioLabel.verdict) ?? String(localized: "No verdict") }
    var sourceLabel: String? { review.verdictSource.map(AdminScenarioLabel.verdictSource) }
    var isHumanVerdict: Bool { AdminScenarioLabel.isHumanSource(review.verdictSource) || review.isReviewed }

    var verdictFields: [AdminAssetField] {
        let r = review
        var fields: [AdminAssetField] = []
        if let outcome = r.reviewOutcome {
            let label = AdminScenarioReviewOutcome(rawValue: outcome)?.label ?? AdminScenarioLabel.verdict(outcome)
            fields.append(.init(title: String(localized: "Review outcome"), value: label))
        }
        if let stars = AdminScenarioFormat.stars(r.reviewRating) {
            fields.append(.init(title: String(localized: "Rating"), value: stars))
        }
        if let by = r.reviewedBy { fields.append(.init(title: String(localized: "Reviewed by"), value: by)) }
        if let date = r.reviewedAt { fields.append(.init(title: String(localized: "Reviewed on"), value: AdminScenarioFormat.date(date))) }
        if r.resolutionConfirmed == true {
            fields.append(.init(title: String(localized: "Fix confirmed"), value: String(localized: "Yes")))
        }
        if r.forceClosed == true {
            fields.append(.init(title: String(localized: "Closed without a fix"), value: String(localized: "Yes")))
        }
        if let date = r.startedAt { fields.append(.init(title: String(localized: "Started"), value: AdminScenarioFormat.date(date))) }
        return fields
    }

    /// I segnali dell'operatore durante la procedura.
    var signals: [AdminScenarioStat] {
        let r = review
        return [
            AdminScenarioStat(title: String(localized: "Failed steps"), value: AdminScenarioFormat.count(r.stepFailures ?? 0),
                              systemImage: "xmark.octagon", tone: .negative),
            AdminScenarioStat(title: String(localized: "Confusing steps"), value: AdminScenarioFormat.count(r.stepConfusions ?? 0),
                              systemImage: "questionmark.bubble", tone: .warning),
            AdminScenarioStat(title: String(localized: "Revised steps"), value: AdminScenarioFormat.count(r.stepRevisions ?? 0),
                              systemImage: "arrow.triangle.2.circlepath"),
            AdminScenarioStat(title: String(localized: "Customized steps"), value: AdminScenarioFormat.count(r.stepCustomizations ?? 0),
                              systemImage: "slider.horizontal.3"),
            AdminScenarioStat(title: String(localized: "Helpful answers"), value: AdminScenarioFormat.count(r.answerUpvotes ?? 0),
                              systemImage: "hand.thumbsup", tone: .positive),
            AdminScenarioStat(title: String(localized: "Unhelpful answers"), value: AdminScenarioFormat.count(r.answerDownvotes ?? 0),
                              systemImage: "hand.thumbsdown", tone: .negative),
        ]
    }

    // MARK: Azioni

    func makeReviewForm() -> AdminScenarioReviewFormViewModel {
        AdminScenarioReviewFormViewModel(backend: reviews.backend, review: review) { [weak reviews] in reviews?.apply($0) }
    }

    func makeNoteForm() -> AdminScenarioNoteFormViewModel {
        AdminScenarioNoteFormViewModel(backend: reviews.backend, review: review) { [weak reviews] in reviews?.append($0) }
    }
}
