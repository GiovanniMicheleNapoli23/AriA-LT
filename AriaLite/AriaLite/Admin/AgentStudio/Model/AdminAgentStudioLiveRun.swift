//
//  AdminAgentStudioLiveRun.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Lo stato di un run che si legge in streaming: ogni riga NDJSON (workflow-runtime.ts / run-v2.ts della web)
//  si somma qui con `apply`, in tempo costante. Valore puro: si prova con righe finte, senza rete.
//  I tipi che non conosciamo si ignorano, come fa il client web.
//

import Foundation

nonisolated struct AdminAgentStudioLiveRun: Sendable {
    /// Quante righe tenere nel registro tecnico (i delta di testo e i progressi non ci entrano).
    static let eventLogLimit = 1_000

    private(set) var runId: String?
    private(set) var mode: AdminAgentStudioRunMode?
    private(set) var phase: Phase = .connecting
    /// Il massimo `seq` visto: da qui riparte GET …/events?after=.
    private(set) var lastSeq = 0
    private(set) var lineCount = 0
    private(set) var startedAt: Date?
    private(set) var budgetMs: Int?
    private(set) var scenarioName: String?

    /// Nodi per chiave (`nodeId` o `nodeId#iteration`) e l'ordine in cui sono comparsi.
    private(set) var nodes: [String: Node] = [:]
    private(set) var nodeOrder: [String] = []
    /// Le chiavi di ogni nodo (più di una dentro un ciclo).
    private(set) var nodeKeys: [String: [String]] = [:]
    private(set) var currentNodeId: String?

    private(set) var done = 0
    private(set) var total = 0
    private(set) var elapsedMs = 0
    private(set) var inputTokens = 0
    private(set) var outputTokens = 0
    private(set) var costEur: Double?

    private(set) var narrative = ""
    private(set) var connectorsReady: Bool?
    private(set) var connectorChecks: [Check] = []
    private(set) var policyChecks: [Check] = []
    private(set) var refusal: Refusal?
    private(set) var pendingApprovals: [PendingApproval] = []
    private(set) var artifacts: [Artifact] = []
    private(set) var summary: Summary?
    private(set) var errorMessage: String?
    private(set) var events: [AdminAgentStudioRunEvent] = []

    init(runId: String? = nil, mode: AdminAgentStudioRunMode? = nil) {
        self.runId = runId
        self.mode = mode
    }

    var isActive: Bool { phase.isActive }

    /// Il numero di tentativi del nodo che sta girando, se è stato rilanciato.
    func attempt(forNode nodeId: String) -> Int? {
        for key in nodeKeys[nodeId] ?? [] {
            if case .running(_, let attempt)? = nodes[key]?.state { return attempt }
        }
        return nil
    }

    // MARK: Chiusure decise fuori dallo stream

    /// Il run risulta finito da un'altra fonte (il record, un annullamento).
    mutating func markFinished(status: String) {
        guard phase.isActive else { return }
        finish(status: status)
    }

    /// La richiesta è fallita prima che il run partisse.
    mutating func fail(message: String) {
        guard phase.isActive else { return }
        errorMessage = message
        phase = .failed(message: message)
    }

    /// Si rilegge tutto dall'inizio (`after=0`): si riparte da zero tenendo solo l'identità del run,
    /// così le righe già viste non si sommano due volte (delta di testo compresi).
    mutating func resetForReplay() {
        self = AdminAgentStudioLiveRun(runId: runId, mode: mode)
    }

    // MARK: Somma

    /// Una riga in più. Le righe senza `type` o di tipo ignoto non cambiano lo stato (restano nel registro se hanno un tipo).
    mutating func apply(_ line: AriaJSON, now: Date = .now) {
        let fields = AdminAgentStudioFields(line)
        if case .number(let seq)? = fields.value("seq"), seq.isFinite, seq > Double(lastSeq), seq < 1e15 {
            lastSeq = Int(seq)
        }
        guard let type = fields.string("type") else { return }
        lineCount += 1

        switch type {
        case "run-start":
            runId = fields.string("runId") ?? runId
            mode = fields.string("mode").flatMap(AdminAgentStudioRunMode.init(rawValue:)) ?? mode
            budgetMs = fields.int("budgetMs") ?? budgetMs
            startedAt = startedAt ?? now
            if phase == .connecting { phase = .checking }
        case "connector-check":
            connectorsReady = fields.bool("ready")
            connectorChecks = fields.array("connectors").compactMap { Check(connector: $0) }
            if phase == .connecting { phase = .checking }
        case "policy-check":
            policyChecks = fields.array("policies").compactMap { Check(policy: $0) }
            if phase == .connecting { phase = .checking }
        case "run-refused":
            refusal = Refusal(json: line)
            phase = .refused
        case "scenario":
            scenarioName = fields.string("name")
        case "step-start":
            stepStart(fields, now: now)
        case "step-end":
            stepEnd(line)
        case "step-retry":
            stepRetry(fields, now: now)
        case "run-progress":
            progress(fields)
        case "narrative-delta":
            // Un delta vuoto non porta nulla.
            if case .string(let text)? = fields.value("text"), !text.isEmpty { narrative += text }
        case "run-summary":
            let body = fields.object("summary")
            guard !body.isEmpty else { break }
            let found = Summary(json: body)
            summary = found
            // La frase intera della sintesi vale più dei delta (e li ripara se ne manca qualcuno).
            if let text = found.narrative { narrative = text }
        case "approval-requested":
            if let approval = PendingApproval(json: line) {
                pendingApprovals.removeAll { $0.id == approval.id }
                pendingApprovals.append(approval)
            }
        case "run-paused":
            if phase.isActive { phase = .paused }
        case "run-resumed":
            if let id = fields.string("approvalId") { pendingApprovals.removeAll { $0.id == id } }
            if phase == .paused { phase = .running }
        case "run-cancelled":
            pendingApprovals.removeAll()
            finish(status: "cancelled")
        case "artifact":
            if let artifact = Artifact(json: line), !artifacts.contains(where: { $0.id == artifact.id }) {
                artifacts.append(artifact)
            }
        case "run-end":
            // `paused` = il run si ferma ad aspettare una persona: non è una fine.
            let status = fields.string("status") ?? "completed"
            if AdminAgentStudioStatus.isActive(status) {
                if phase.isActive { phase = .paused }
            } else {
                finish(status: status)
            }
        case "done":
            finish(status: fields.string("status") ?? "completed")
        case "error":
            let message = fields.string("message", "error") ?? String(localized: "The run failed")
            errorMessage = message
            if phase.isActive { phase = .failed(message: message) }
        default:
            break  // branch, loop-pass, budget, orchestrator-plan…: solo nel registro
        }

        if type != "narrative-delta", type != "run-progress", events.count < Self.eventLogLimit {
            events.append(AdminAgentStudioRunEvent(index: lineCount, json: line))
        }
    }

    // MARK: Privato

    /// Chiude il run; non riapre uno già chiuso (un `done` dopo un `error` non lo cambia).
    private mutating func finish(status: String) {
        guard phase.isActive else { return }
        phase = .finished(status: status)
        currentNodeId = nil
    }

    /// Prima riga "di lavoro": dal controllo iniziale si passa a running.
    private mutating func startRunning() {
        if phase == .connecting || phase == .checking { phase = .running }
    }

    private mutating func touch(nodeId: String, iteration: Int?, state: NodeState) {
        let key = Self.key(nodeId: nodeId, iteration: iteration)
        if nodes[key] == nil {
            nodeOrder.append(key)
            nodeKeys[nodeId, default: []].append(key)
        }
        nodes[key] = Node(nodeId: nodeId, iteration: iteration, state: state)
    }

    private mutating func stepStart(_ fields: AdminAgentStudioFields, now: Date) {
        guard let nodeId = fields.string("nodeId") else { return }
        let iteration = fields.int("iteration")
        // Un replay non riporta in corso un nodo già concluso.
        if case .finished? = nodes[Self.key(nodeId: nodeId, iteration: iteration)]?.state { return }
        touch(nodeId: nodeId, iteration: iteration, state: .running(startedAt: now, attempt: nil))
        currentNodeId = nodeId
        startRunning()
    }

    private mutating func stepEnd(_ line: AriaJSON) {
        guard let step = AdminAgentStudioRunStep(json: line) else { return }
        touch(nodeId: step.nodeId, iteration: step.iteration, state: .finished(step))
        if currentNodeId == step.nodeId { currentNodeId = nil }
        startRunning()
    }

    private mutating func stepRetry(_ fields: AdminAgentStudioFields, now: Date) {
        guard let nodeId = fields.string("nodeId") else { return }
        let iteration = fields.int("iteration")
        let attempt = fields.int("attempt") ?? 2
        switch nodes[Self.key(nodeId: nodeId, iteration: iteration)]?.state {
        case .running(let startedAt, _)?:
            touch(nodeId: nodeId, iteration: iteration, state: .running(startedAt: startedAt, attempt: attempt))
        case .finished?:
            break
        case nil:
            touch(nodeId: nodeId, iteration: iteration, state: .running(startedAt: now, attempt: attempt))
            currentNodeId = nodeId
        }
        startRunning()
    }

    private mutating func progress(_ fields: AdminAgentStudioFields) {
        done = fields.int("done") ?? done
        total = fields.int("total") ?? total
        elapsedMs = fields.int("elapsedMs") ?? elapsedMs
        let tokens = fields.object("tokens")
        inputTokens = tokens.int("input") ?? inputTokens
        outputTokens = tokens.int("output") ?? outputTokens
        costEur = fields.double("costEur") ?? costEur
        startRunning()
    }
}
