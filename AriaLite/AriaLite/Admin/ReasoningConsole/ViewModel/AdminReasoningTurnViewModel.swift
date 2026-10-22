//
//  AdminReasoningTurnViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un turno della sessione: la trace completa (nodi, fasi, tempi, errori) e l'attribution della
//  risposta, caricate insieme. Tutto si prepara qui una volta sola: la vista mostra e basta.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminReasoningTurnViewModel {
    @ObservationIgnored private let backend: AriaBackend
    let summary: AdminReasoningTurnSummary

    private(set) var trace: AdminReasoningTrace?
    private(set) var nodes: [AdminReasoningNode] = []
    private(set) var phases: [AdminReasoningPhase] = []
    private(set) var traceError: String?
    /// 404: il turno non ha (o non ha ancora) una trace. Si può riprovare a mano, senza insistere.
    private(set) var traceMissing = false

    private(set) var attribution: AdminReasoningAttribution?
    private(set) var attributionError: String?
    /// 409 `attribution_unavailable`: definitivo, niente "Retry".
    private(set) var attributionUnavailable = false

    private(set) var isLoading = false
    private(set) var hasLoaded = false

    init(backend: AriaBackend, summary: AdminReasoningTurnSummary) {
        self.backend = backend
        self.summary = summary
    }

    var title: String {
        summary.episodeNumber.map { String(localized: "Turn \($0)") } ?? String(localized: "Turn")
    }

    // MARK: Panoramica

    var stats: [AdminReasoningStat] {
        var stats: [AdminReasoningStat] = []
        if let duration = AdminReasoningFormat.duration(ms: summary.durationMs) {
            stats.append(AdminReasoningStat(title: String(localized: "Duration"), value: duration, systemImage: "timer"))
        }
        let nodeCount = summary.nodeCount ?? (nodes.isEmpty ? nil : nodes.count)
        if let nodeCount {
            stats.append(AdminReasoningStat(title: String(localized: "Nodes"), value: nodeCount.formatted(),
                                            systemImage: "point.3.connected.trianglepath.dotted"))
        }
        if let grounding = AdminReasoningFormat.percent(summary.groundingScore) {
            stats.append(AdminReasoningStat(title: String(localized: "Grounding"), value: grounding, systemImage: "checkmark.seal"))
        }
        if let confidence = AdminReasoningFormat.percent(summary.confidence) {
            stats.append(AdminReasoningStat(title: String(localized: "Confidence"), value: confidence, systemImage: "gauge.medium"))
        }
        if let candidates = summary.candidateCount, candidates > 0 {
            stats.append(AdminReasoningStat(title: String(localized: "Candidates"), value: candidates.formatted(),
                                            systemImage: "list.bullet.rectangle"))
        }
        return stats
    }

    var fields: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Response ID"), summary.responseId)
        add(String(localized: "Started"), (trace?.created ?? summary.created)?.formatted(date: .abbreviated, time: .standard))
        add(String(localized: "Agent"), summary.agent)
        add(String(localized: "Grounding advice"), summary.groundingRecommendation.map(AdminReasoningFormat.humanize))
        add(String(localized: "Ungrounded claims"), summary.ungroundedCount.map { $0.formatted() })
        if summary.contextVoided == true { add(String(localized: "Context"), String(localized: "Voided")) }
        add(String(localized: "Elapsed"), AdminReasoningFormat.duration(ms: summary.elapsedMs.flatMap { $0 > 0 ? $0 : nil }))
        add(String(localized: "Busy"), AdminReasoningFormat.duration(ms: summary.busyMs.flatMap { $0 > 0 ? $0 : nil }))
        add(String(localized: "Node work"), AdminReasoningFormat.duration(ms: summary.nodeWorkMs.flatMap { $0 > 0 ? $0 : nil }))
        return rows
    }

    var failedNodeCount: Int { nodes.filter(\.hasError).count }

    // MARK: Attribution

    /// La riga onesta che il server chiede alla UI: "più vicino", non "derivato da".
    var attributionNote: String {
        let method = attribution?.method ?? "embedding-cosine"
        let floor = AdminReasoningFormat.score(attribution?.floor) ?? "—"
        return String(localized: "Each sentence is matched to the prompt source it most resembles (\(method), floor \(floor)). Resemblance is not proof the answer came from it.")
    }

    var attributionStats: [AdminReasoningStat] {
        guard let summary = attribution?.summary else { return [] }
        var stats: [AdminReasoningStat] = []
        if let total = summary.total {
            stats.append(AdminReasoningStat(title: String(localized: "Sentences"), value: total.formatted(), systemImage: "text.alignleft"))
        }
        if let sourced = summary.sourced {
            stats.append(AdminReasoningStat(title: String(localized: "Sourced"), value: sourced.formatted(), systemImage: "link"))
        }
        if let unsupported = summary.unsupported {
            stats.append(AdminReasoningStat(title: String(localized: "Unsupported"), value: unsupported.formatted(),
                                            systemImage: "questionmark.circle"))
        }
        return stats
    }

    /// Le frasi per tipo di fonte, le più frequenti prima ("document 4", "fact 2").
    var kindBreakdown: [(kind: String, count: Int)] {
        (attribution?.summary?.byKind ?? [:])
            .map { (kind: AdminReasoningFormat.humanize($0.key), count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.kind < $1.kind }
    }

    var sentences: [AdminReasoningSentence] { attribution?.sentences ?? [] }

    /// Le fonti che hanno raccolto almeno una frase, le più usate prima.
    var usedSpans: [AdminReasoningSpan] {
        (attribution?.spans ?? []).filter { ($0.hits ?? 0) > 0 }.sorted { ($0.hits ?? 0) > ($1.hits ?? 0) }
    }

    func spanLabel(for sentence: AdminReasoningSentence) -> String? {
        guard let index = sentence.spanIndex,
              let span = attribution?.spans.first(where: { $0.index == index }) else { return nil }
        return AdminReasoningFormat.trimmed(span.label) ?? span.kind.map(AdminReasoningFormat.humanize)
    }

    func scoreText(for sentence: AdminReasoningSentence) -> String? {
        AdminReasoningFormat.score(sentence.score)
    }

    // MARK: Caricamento

    func load() async {
        guard let companyId = backend.activeCompanyId else {
            traceError = AriaError.missingCompany.localizedDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        let responseId = summary.responseId
        let api = backend.api
        async let traceResult = Self.result { try await api.call(AdminReasoningConsoleAPI.turnTrace(companyId: companyId, responseId: responseId)) }
        async let attributionResult = Self.result { try await api.call(AdminReasoningConsoleAPI.attribution(companyId: companyId, responseId: responseId)) }
        let (traceOutcome, attributionOutcome) = await (traceResult, attributionResult)
        guard !Task.isCancelled else { return }
        apply(traceOutcome)
        apply(attributionOutcome)
        hasLoaded = true
    }

    private func apply(_ outcome: Result<AdminReasoningTrace, any Error>) {
        switch outcome {
        case .success(let trace):
            self.trace = trace
            nodes = AdminReasoningNode.nodes(of: trace)
            phases = AdminReasoningPhase.phases(of: trace)
            traceError = nil
            traceMissing = false
        case .failure(let error):
            traceMissing = AdminReasoningConsoleFailure.isMissingTrace(error)
            traceError = traceMissing
                ? String(localized: "This turn has no trace. Some turns never record one (direct tool calls, failed writes); a turn that just ended may need a moment.")
                : AdminReasoningConsoleFailure.message(for: error, backend: backend)
        }
    }

    private func apply(_ outcome: Result<AdminReasoningAttribution, any Error>) {
        switch outcome {
        case .success(let attribution):
            self.attribution = attribution
            attributionError = nil
            attributionUnavailable = false
        case .failure(let error):
            attributionUnavailable = AdminReasoningConsoleFailure.isUnavailable(error)
            if attributionUnavailable {
                let reason = AdminReasoningConsoleFailure.serverDetail(error)
                attributionError = reason.map { String(localized: "Attribution isn't available for this turn: \($0)") }
                    ?? String(localized: "Attribution isn't available for this turn.")
            } else {
                attributionError = AdminReasoningConsoleFailure.message(for: error, backend: backend)
            }
        }
    }

    /// Una chiamata come Result: trace e attribution falliscono ognuna per conto suo.
    nonisolated private static func result<Value: Sendable>(
        _ operation: @Sendable () async throws -> Value) async -> Result<Value, any Error> {
        do { return .success(try await operation()) } catch { return .failure(error) }
    }
}
