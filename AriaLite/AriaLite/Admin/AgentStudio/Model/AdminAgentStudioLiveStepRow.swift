//
//  AdminAgentStudioLiveStepRow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Una riga della cronologia di un run: un passo del workflow con il suo stato (in attesa, in corso, eseguito…).
//  `rows(steps:live:record:)` unisce i passi del grafo, gli stati letti in streaming e il record salvato.
//

import Foundation

nonisolated struct AdminAgentStudioLiveStepRow: Sendable, Identifiable, Hashable {
    enum State: Sendable, Hashable {
        case waiting, running, ran, simulated, needsApproval, blocked, unconfigured, skipped, failed
    }

    /// `nodeId`, o `nodeId#iteration` dentro un ciclo.
    let id: String
    /// Posizione 1-based nella cronologia.
    let index: Int
    let nodeId: String
    let iteration: Int?
    let title: String
    /// Cosa fa il passo (compito dell'agente, azione…), se il grafo lo dice.
    let subtitle: String?
    let kind: String
    let systemImage: String
    let state: State
    let reason: String?
    let output: String?
    let metricsLine: String?
    let approvalId: String?
    /// Il tentativo in corso, se il passo è stato rilanciato.
    let attempt: Int?
    /// Da quando gira (per il cronometro della riga in corso).
    let startedAt: Date?

    var isFinished: Bool {
        switch state {
        case .waiting, .running: false
        default: true
        }
    }

    // MARK: Costruzione

    /// I passi del workflow in ordine di grafo, ognuno con il suo stato; i nodi comparsi nello stream
    /// o nel record ma non nel grafo seguono in fondo. A run concluso un passo mai raggiunto vale "saltato"
    /// (a meno che il run sia stato rifiutato o sia fallito: lì non è partito nulla).
    static func rows(steps: [AdminAgentStudioWorkflowStep], live: AdminAgentStudioLiveRun,
                     record: [AdminAgentStudioRunStep]) -> [Self] {
        var recordByNode: [String: [AdminAgentStudioRunStep]] = [:]
        for step in record { recordByNode[step.nodeId, default: []].append(step) }
        let stepIds = Set(steps.map(\.id))
        // Run chiuso: un passo mai raggiunto vale "saltato"; uno ancora in corso, se il run è fallito, "fallito".
        var closed = false
        var runFailed = false
        var failure: String?
        switch live.phase {
        case .finished(let status):
            closed = true
            runFailed = AdminAgentStudioStatus.tone(for: status) == .negative
        case .failed(let message):
            runFailed = true
            failure = message
        default:
            break
        }

        var rows: [Self] = []
        func add(_ node: AdminAgentStudioWorkflowStep?, nodeId: String, iteration: Int?,
                 state: AdminAgentStudioLiveRun.NodeState?) {
            rows.append(Self(index: rows.count + 1, node: node, nodeId: nodeId, iteration: iteration, state: state,
                             closed: closed, runFailed: runFailed, failure: failure,
                             approvalId: live.pendingApprovals.first { $0.nodeId == nodeId }?.id))
        }

        for step in steps {
            if let keys = live.nodeKeys[step.id], !keys.isEmpty {
                for key in keys { if let node = live.nodes[key] { add(step, nodeId: step.id, iteration: node.iteration, state: node.state) } }
            } else if let saved = recordByNode[step.id] {
                for item in saved { add(step, nodeId: step.id, iteration: item.iteration, state: .finished(item)) }
            } else {
                add(step, nodeId: step.id, iteration: nil, state: nil)
            }
        }
        // Fuori dal grafo (il workflow è cambiato dopo il run, o non è caricato): nell'ordine in cui sono arrivati.
        for key in live.nodeOrder {
            guard let node = live.nodes[key], !stepIds.contains(node.nodeId) else { continue }
            add(nil, nodeId: node.nodeId, iteration: node.iteration, state: node.state)
        }
        for item in record where !stepIds.contains(item.nodeId) && live.nodeKeys[item.nodeId] == nil {
            add(nil, nodeId: item.nodeId, iteration: item.iteration, state: .finished(item))
        }
        return rows
    }

    private init(index: Int, node: AdminAgentStudioWorkflowStep?, nodeId: String, iteration: Int?,
                 state nodeState: AdminAgentStudioLiveRun.NodeState?, closed: Bool, runFailed: Bool, failure: String?,
                 approvalId pending: String?) {
        self.index = index
        self.nodeId = nodeId
        self.iteration = iteration
        id = AdminAgentStudioLiveRun.key(nodeId: nodeId, iteration: iteration)
        kind = node?.kind ?? "unknown"
        systemImage = node?.systemImage ?? "square.dashed"
        subtitle = node?.detail
        switch nodeState {
        case nil:
            state = closed ? .skipped : .waiting
            reason = nil; output = nil; metricsLine = nil; approvalId = nil; attempt = nil; startedAt = nil
            title = node?.title ?? Self.humanized(nodeId)
        case .running(let started, let tries)?:
            state = runFailed ? .failed : (closed ? .skipped : .running)
            reason = runFailed ? failure : nil
            output = nil; metricsLine = nil; approvalId = nil
            attempt = tries; startedAt = started
            title = node?.title ?? Self.humanized(nodeId)
        case .finished(let step)?:
            state = Self.stateOf(step)
            reason = step.reason; output = step.output; metricsLine = step.metricsLine
            approvalId = step.approvalId ?? pending
            attempt = nil; startedAt = nil
            title = node?.title ?? step.agentName ?? Self.humanized(nodeId)
        }
    }

    private static func stateOf(_ step: AdminAgentStudioRunStep) -> State {
        switch step.outcome.lowercased().replacingOccurrences(of: "-", with: "_") {
        case "needs_approval": .needsApproval
        case "blocked": .blocked
        case "unconfigured": .unconfigured
        case "skipped": .skipped
        case "error", "failed": .failed
        default: step.simulated ? .simulated : .ran
        }
    }

    private static func humanized(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
    }
}
