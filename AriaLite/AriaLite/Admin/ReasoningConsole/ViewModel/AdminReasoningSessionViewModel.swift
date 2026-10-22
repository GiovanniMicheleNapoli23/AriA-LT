//
//  AdminReasoningSessionViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sessione, come /settings/sessions/{sessionId} della web: la timeline dei turni con tempi,
//  nodi e grounding (GET …/turn-traces?sessionId=), più rinomina ed elimina.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminReasoningSessionViewModel {
    @ObservationIgnored private let backend: AriaBackend
    let editor: AdminReasoningSessionEditor
    @ObservationIgnored var onRenamed: (AriaSessionSummary) -> Void = { _ in }
    @ObservationIgnored var onDeleted: (String) -> Void = { _ in }

    private(set) var session: AriaSessionSummary
    private(set) var turns: [AdminReasoningTurnSummary] = []
    private(set) var total: Int?
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    /// La sessione è stata eliminata: la vista torna alla lista.
    private(set) var isDeleted = false

    init(backend: AriaBackend, session: AriaSessionSummary) {
        self.backend = backend
        self.session = session
        editor = AdminReasoningSessionEditor(backend: backend)
        editor.onRenamed = { [weak self] renamed in
            self?.session = renamed
            self?.onRenamed(renamed)
        }
        editor.onDeleted = { [weak self] id in
            self?.isDeleted = true
            self?.onDeleted(id)
        }
    }

    var title: String { AdminReasoningFormat.trimmed(session.title) ?? String(localized: "Untitled session") }

    // MARK: Timeline

    /// In ordine di conversazione: il primo turno in alto (il server li dà dal più recente).
    var timeline: [AdminReasoningTurnSummary] {
        turns.sorted { lhs, rhs in
            if let l = lhs.episodeNumber, let r = rhs.episodeNumber, l != r { return l < r }
            return (lhs.created ?? .distantPast) < (rhs.created ?? .distantPast)
        }
    }

    /// Il server ne ha di più di quelli scaricati (al massimo 200, senza offset): si dice quanti mancano.
    var truncationNote: String? {
        guard hasMore || (total ?? 0) > turns.count else { return nil }
        let shown = turns.count
        let all = max(total ?? shown, shown)
        return String(localized: "Showing the latest \(shown) of \(all) turns.")
    }

    var stats: [AdminReasoningStat] {
        guard !turns.isEmpty else { return [] }
        var stats = [AdminReasoningStat(title: String(localized: "Turns"), value: (total ?? turns.count).formatted(),
                                        systemImage: "text.bubble")]
        let durations = turns.compactMap(\.durationMs)
        if !durations.isEmpty, let average = AdminReasoningFormat.duration(ms: durations.reduce(0, +) / durations.count) {
            stats.append(AdminReasoningStat(title: String(localized: "Avg. duration"), value: average, systemImage: "timer"))
        }
        let scores = turns.compactMap(\.groundingScore)
        if !scores.isEmpty, let average = AdminReasoningFormat.percent(scores.reduce(0, +) / Double(scores.count)) {
            stats.append(AdminReasoningStat(title: String(localized: "Avg. grounding"), value: average,
                                            systemImage: "checkmark.seal"))
        }
        let ungrounded = turns.compactMap(\.ungroundedCount).reduce(0, +)
        if ungrounded > 0 {
            stats.append(AdminReasoningStat(title: String(localized: "Ungrounded claims"), value: ungrounded.formatted(),
                                            systemImage: "exclamationmark.bubble"))
        }
        return stats
    }

    var fields: [AdminAssetField] {
        var rows = [AdminAssetField(title: String(localized: "Session ID"), value: session.sessionId)]
        if let status = AdminReasoningFormat.trimmed(session.status) {
            rows.append(AdminAssetField(title: String(localized: "Status"), value: AdminReasoningFormat.humanize(status)))
        }
        if let created = AriaDate.parse(session.createdAt) {
            rows.append(AdminAssetField(title: String(localized: "Started"),
                                        value: created.formatted(date: .abbreviated, time: .shortened)))
        }
        if let last = session.lastActivity {
            rows.append(AdminAssetField(title: String(localized: "Last activity"),
                                        value: last.formatted(date: .abbreviated, time: .shortened)))
        }
        return rows
    }

    // MARK: Caricamento

    func load() async {
        guard let companyId = backend.activeCompanyId else {
            errorMessage = AriaError.missingCompany.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await backend.api.call(
                AdminReasoningConsoleAPI.turnTraces(companyId: companyId, sessionId: session.sessionId))
            guard !Task.isCancelled else { return }
            turns = response.traces
            total = response.total
            hasMore = response.hasMore
            hasLoaded = true
            errorMessage = nil
        } catch {
            guard let message = AdminReasoningConsoleFailure.message(for: error, backend: backend) else { return }
            errorMessage = message
        }
    }
}
