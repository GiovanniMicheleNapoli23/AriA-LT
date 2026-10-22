//
//  AdminCraftedSessionViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sessione conclusa vista da Crafted: verdetto, passi, cose imparate, la conversazione in sola
//  lettura (con le card di Aria, che si possono fissare fra i widget), rinomina e report Word.
//  Messaggi, rinomina e report passano da AriaChatAPI.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminCraftedSessionViewModel {
    let backend: AriaBackend
    private(set) var review: AdminCraftedSessionReview
    let learned: [AdminCraftedLearned]
    let steps: [AdminCraftedSessionStep]

    private(set) var messages: [AriaAgentMessage] = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private(set) var report: AriaReportFile?
    private(set) var preparingReport = false

    var renameText = ""
    var showsRename = false
    private(set) var isRenaming = false

    /// Le card già fissate in questa visita (id dell'artifact), e quella in corso.
    private(set) var pinnedIds: Set<String> = []
    private(set) var pinningId: String?

    var actionError: String?
    var showsActionError = false

    @ObservationIgnored private let nextPosition: () -> Int
    @ObservationIgnored private let onPinned: (AdminCraftedWidget) -> Void
    @ObservationIgnored private let onRenamed: (String) -> Void

    private var chat: AriaChatAPI { AriaChatAPI(api: backend.api) }

    init(backend: AriaBackend, review: AdminCraftedSessionReview, learned: [AdminCraftedLearned],
         steps: [AdminCraftedSessionStep], nextPosition: @escaping () -> Int,
         onPinned: @escaping (AdminCraftedWidget) -> Void, onRenamed: @escaping (String) -> Void) {
        self.backend = backend
        self.review = review
        self.learned = learned
        self.steps = steps
        self.nextPosition = nextPosition
        self.onPinned = onPinned
        self.onRenamed = onRenamed
    }

    // MARK: Intestazione

    var title: String { review.displayTitle }
    var verdictLabel: String { AdminCraftedVerdict.label(review.verdict) }
    var verdictSourceLabel: String? { AdminCraftedVerdict.sourceLabel(review.verdictSource) }

    var facts: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        if let alarm = review.alarmCode, !alarm.isEmpty { rows.append(.init(title: String(localized: "Alarm"), value: alarm)) }
        if let episode = review.episode, episode > 1 { rows.append(.init(title: String(localized: "Procedure"), value: "\(episode)")) }
        if let date = review.date { rows.append(.init(title: String(localized: "Last activity"), value: date.formatted(date: .abbreviated, time: .shortened))) }
        if let outcome = review.reviewOutcome, !outcome.isEmpty {
            rows.append(.init(title: String(localized: "Operator review"), value: AdminCraftedVerdict.label(outcome)))
        }
        if let rating = review.reviewRating { rows.append(.init(title: String(localized: "Rating"), value: "\(rating)/5")) }
        if let issues = review.reviewIssues, !issues.isEmpty { rows.append(.init(title: String(localized: "Reported issues"), value: issues)) }
        if review.forceClosed == true { rows.append(.init(title: String(localized: "Closed"), value: String(localized: "Forced"))) }
        return rows
    }

    // MARK: Conversazione

    /// I messaggi della procedura mostrata: se il server dà l'episodio, solo quelli di questo.
    var visibleMessages: [AriaAgentMessage] {
        guard let episode = review.episode, messages.contains(where: { $0.episode != nil }) else { return messages }
        let filtered = messages.filter { $0.episode == nil || $0.episode == episode }
        return filtered.isEmpty ? messages : filtered
    }

    /// Le card della risposta da mostrare: quelle in evidenza prima.
    func artifacts(of message: AriaAgentMessage) -> [AriaArtifact] {
        message.artifacts.filter(\.isDeliverable) + message.artifacts.filter { !$0.isDeliverable }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await chat.messages(sessionId: review.sessionId)
            guard !Task.isCancelled else { return }
            messages = rows.map(AriaAgentMessage.init(persisted:))
                .filter { !$0.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.artifacts.isEmpty }
            hasLoaded = true
            errorMessage = nil
        } catch {
            guard let message = AdminCraftedFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }

    /// Un percorso della web dalle card (es. /work-orders/12): si apre nel browser, sempre filtrato.
    func webURL(for target: String) -> URL? {
        let url = URL(string: target).flatMap { $0.scheme == nil ? URL(string: target, relativeTo: backend.webURL)?.absoluteURL : $0 }
        return url.flatMap(AriaURLPolicy.external)
    }

    // MARK: Fissare una card

    /// Si può fissare solo una card che dice da quale tool viene: il widget riesegue quello.
    func canPin(_ artifact: AriaArtifact) -> Bool {
        artifact.source?.toolName.isEmpty == false && !pinnedIds.contains(artifact.id) && pinningId == nil
    }

    func isPinned(_ artifact: AriaArtifact) -> Bool { pinnedIds.contains(artifact.id) }

    func pin(_ artifact: AriaArtifact) async {
        guard canPin(artifact), let source = artifact.source else { return }
        pinningId = artifact.id
        defer { pinningId = nil }
        let title = artifact.data["title"]?.nonEmptyString ?? AdminCraftedKind.label(artifact.kind)
        let body = AdminCraftedWidgetCreate(title: title, description: artifact.data["subtitle"]?.nonEmptyString,
                                            kind: artifact.kind, toolName: source.toolName,
                                            toolArgs: source.toolArgs ?? [:], position: nextPosition())
        do {
            let widget = try await backend.api.call(AdminCraftedAPI.createWidget(body))
            pinnedIds.insert(artifact.id)
            onPinned(widget)
        } catch {
            fail(error)
        }
    }

    // MARK: Rinomina

    func startRename() {
        renameText = review.title ?? ""
        showsRename = true
    }

    func rename() async {
        let title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != review.title else { return }
        isRenaming = true
        defer { isRenaming = false }
        do {
            try await chat.rename(sessionId: review.sessionId, title: title)
            review = review.withTitle(title)
            onRenamed(title)
        } catch {
            fail(error)
        }
    }

    // MARK: Report

    /// Il report Word della procedura, nella lingua dell'app, scritto in un file temporaneo da condividere.
    func prepareReport() async {
        guard let companyId = backend.activeCompanyId else { return }
        preparingReport = true
        defer { preparingReport = false }
        do {
            report = try await chat.reportDocument(companyId: companyId, sessionId: review.sessionId,
                                                   locale: backend.api.context.locale, episode: review.episode)
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: any Error) {
        guard let message = AdminCraftedFailure.message(for: error, backend: backend) else { return }
        actionError = message
        showsActionError = true
    }
}
