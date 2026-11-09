//
//  AdminScenarioReviewFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form "Correct verdict": l'esito che l'admin sa giusto (rifà i conteggi dello scenario), un voto
//  facoltativo 1…5 e i problemi riscontrati. Scrive sulla procedura a schermo (`episode`), non su quella in corso.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioReviewFormViewModel: Identifiable {
    let backend: AriaBackend
    let review: AdminScenarioSessionReview
    @ObservationIgnored private let onSaved: (AdminScenarioSessionReview) -> Void

    var outcome: AdminScenarioReviewOutcome
    /// 0 = nessun voto.
    var rating: Int
    var issues: String
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(backend: AriaBackend, review: AdminScenarioSessionReview,
         onSaved: @escaping (AdminScenarioSessionReview) -> Void) {
        self.backend = backend
        self.review = review
        self.onSaved = onSaved
        // Si parte da quello che c'è: la revisione precedente, o il verdetto di Aria.
        let current = review.reviewOutcome ?? review.verdict
        outcome = current.flatMap(AdminScenarioReviewOutcome.init(rawValue:)) ?? .resolved
        rating = review.reviewRating.flatMap { (1...5).contains($0) ? $0 : nil } ?? 0
        issues = review.reviewIssues ?? ""
    }

    var title: String { review.displayTitle }
    var canSave: Bool { !isSaving }

    /// `true` se salvato (la vista chiude il form).
    func save() async -> Bool {
        guard canSave else { return false }
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return false
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let trimmed = issues.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = AdminScenarioReviewRequest(outcome: outcome.rawValue, rating: rating == 0 ? nil : rating,
                                              issues: trimmed.isEmpty ? nil : trimmed)
        do {
            let saved = try await backend.api.call(AdminScenarioAnalysisAPI.correctReview(
                companyId: companyId, sessionId: review.sessionId, episode: review.episode, body))
            onSaved(saved)
            return true
        } catch {
            errorMessage = AdminScenarioFailure.message(for: error, backend: backend)
            return false
        }
    }
}
