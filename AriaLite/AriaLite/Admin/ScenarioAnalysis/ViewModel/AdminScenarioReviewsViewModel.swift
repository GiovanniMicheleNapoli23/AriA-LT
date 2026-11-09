//
//  AdminScenarioReviewsViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La scheda Reviews: le sessioni concluse con il loro verdetto e chi l'ha dato, il riepilogo e le liste
//  di feedback, passi e cose imparate (piatte, di tutta l'azienda: qui si dividono per sessione e procedura).
//  Non c'è paginazione: si alza `limit` (fino a 500) con "Show more".
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminScenarioReviewsViewModel {
    let backend: AriaBackend

    private(set) var sessions: [AdminScenarioSessionReview] = []
    private(set) var summary: AdminScenarioReviewSummary?
    private(set) var feedback: [AdminScenarioFeedbackEvent] = []
    private(set) var learned: [AdminScenarioLearned] = []
    private(set) var steps: [AdminScenarioStep] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?
    private(set) var limit = AdminScenarioReviewsViewModel.pageSize
    @ObservationIgnored private var loadedScope: String?

    var searchText = ""
    var filter: AdminScenarioReviewFilter = .all
    var verdictFilter: String?

    static let pageSize = 100
    static let maxLimit = 500

    init(backend: AriaBackend) {
        self.backend = backend
    }

    /// Azienda e stabilimento: cambiandoli la lista vecchia non vale più.
    private var scope: String { "\(backend.activeCompanyId ?? "-")|\(backend.activePlantId ?? "-")" }
    var loadKey: String { "\(scope)|\(limit)" }

    // MARK: Lista

    var visibleSessions: [AdminScenarioSessionReview] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sessions
            .filter {
                switch filter {
                case .all: true
                case .awaiting: !$0.isReviewed
                case .reviewed: $0.isReviewed
                }
            }
            .filter { verdictFilter == nil || $0.verdict == verdictFilter }
            .filter { query.isEmpty || $0.searchableFields.contains { $0.localizedStandardContains(query) } }
    }

    /// I verdetti presenti, per il filtro.
    var verdicts: [String] { Set(sessions.compactMap(\.verdict)).sorted() }

    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasLocalFilters: Bool { filter != .all || verdictFilter != nil }
    var verdictFilterLabel: String { verdictFilter.map(AdminScenarioLabel.verdict) ?? String(localized: "All") }

    func clearFilters() {
        filter = .all
        verdictFilter = nil
    }

    var canShowMore: Bool { hasLoaded && sessions.count >= limit && limit < Self.maxLimit }

    func showMore() {
        limit = min(limit + Self.pageSize, Self.maxLimit)
    }

    var subtitle: String {
        let count = visibleSessions.count
        return String(localized: "\(count) sessions")
    }

    func session(id: String) -> AdminScenarioSessionReview? {
        sessions.first { $0.id == id }
    }

    /// Il riepilogo in tessere: quante, quante da rivedere, come sono andate.
    var overview: [AdminScenarioStat] {
        let s = summary
        return [
            AdminScenarioStat(title: String(localized: "Sessions"), value: AdminScenarioFormat.count(s?.sessions ?? sessions.count),
                              systemImage: "bubble.left.and.text.bubble.right"),
            AdminScenarioStat(title: String(localized: "Awaiting review"), value: AdminScenarioFormat.count(s?.awaitingReview),
                              systemImage: "hourglass", tone: .warning),
            AdminScenarioStat(title: String(localized: "Reviewed share"), value: AdminScenarioFormat.percent(s?.reviewedShare),
                              systemImage: "person.fill.checkmark"),
            AdminScenarioStat(title: String(localized: "Average rating"), value: AdminScenarioFormat.rating(s?.avgRating),
                              systemImage: "star"),
            AdminScenarioStat(title: String(localized: "Resolved sessions"), value: AdminScenarioFormat.count(s?.resolved),
                              systemImage: "checkmark.circle", tone: .positive),
            AdminScenarioStat(title: String(localized: "Unresolved sessions"), value: AdminScenarioFormat.count(s?.unresolved),
                              systemImage: "xmark.circle", tone: .negative),
            AdminScenarioStat(title: String(localized: "Unclear sessions"), value: AdminScenarioFormat.count(s?.unclear),
                              systemImage: "questionmark.circle", tone: .neutral),
            AdminScenarioStat(title: String(localized: "Reported issues"), value: AdminScenarioFormat.count(s?.reportedIssues),
                              systemImage: "exclamationmark.bubble", tone: .warning),
        ]
    }

    // MARK: Per una sessione

    /// La traccia di una procedura, dalla più vecchia. Un evento senza procedura vale per la chat intera.
    func feedback(for review: AdminScenarioSessionReview) -> [AdminScenarioFeedbackEvent] {
        feedback
            .filter { $0.sessionId == review.sessionId && ($0.episode == nil || $0.episode == review.episode) }
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    func steps(for review: AdminScenarioSessionReview) -> [AdminScenarioStep] {
        steps.filter { $0.sessionId == review.sessionId && ($0.episode ?? 1) == review.episode }
    }

    /// Le cose imparate non dicono la procedura: valgono per la chat.
    func learned(for review: AdminScenarioSessionReview) -> [AdminScenarioLearned] {
        learned.filter { $0.sessionId == review.sessionId }
    }

    // MARK: Caricamento

    func load() async {
        let scope = scope
        if scope != loadedScope {
            sessions = []
            summary = nil
            feedback = []
            learned = []
            steps = []
            hasLoaded = false
            errorMessage = nil
            loadedScope = scope
        }
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        let key = loadKey
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(AdminScenarioAnalysisAPI.sessionReviews(
                companyId: companyId, plantId: backend.activePlantId, limit: limit))
            guard key == loadKey, !Task.isCancelled else { return }
            sessions = response.sessions
            summary = response.summary
            feedback = response.feedback
            learned = response.learned
            steps = response.steps
            hasLoaded = true
            errorMessage = nil
            lastUpdated = .now
            if let verdict = verdictFilter, !verdicts.contains(verdict) { verdictFilter = nil }
        } catch {
            guard key == loadKey, let message = AdminScenarioFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    // MARK: Dopo una scrittura

    /// Il verdetto corretto sostituisce la riga subito; il riepilogo (calcolato dal server) si riaggiorna dopo.
    func apply(_ review: AdminScenarioSessionReview) {
        if let index = sessions.firstIndex(where: { $0.id == review.id }) {
            sessions[index] = review
        }
        Task { await load() }
    }

    func append(_ event: AdminScenarioFeedbackEvent) {
        feedback.removeAll { $0.id == event.id }
        feedback.append(event)
    }

    func makeDetailViewModel(for review: AdminScenarioSessionReview) -> AdminScenarioReviewDetailViewModel {
        AdminScenarioReviewDetailViewModel(reviews: self, snapshot: review)
    }

    func reset() {
        sessions = []
        summary = nil
        feedback = []
        learned = []
        steps = []
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        lastUpdated = nil
        limit = Self.pageSize
        loadedScope = nil
        searchText = ""
        filter = .all
        verdictFilter = nil
    }
}
