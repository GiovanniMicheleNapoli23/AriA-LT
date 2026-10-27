//
//  AdminAgentStudioRun.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un run di un workflow (WorkflowRunRecord): modalità, stato, contatori, il verdetto di ogni nodo,
//  i blocchi che fermano un run reale e il riassunto. Il riassunto annidato arriva in snake_case.
//

import Foundation

nonisolated struct AdminAgentStudioRun: AdminAgentStudioJSONModel, Identifiable {
    static let listKeys = ["runs", "items"]

    let id: String
    let workflowId: String?
    let workflowName: String?
    let mode: String?
    let source: String?
    let status: String?
    let agents: [String]
    let startedAt: Date?
    let finishedAt: Date?
    let startedBy: String?
    let scenarioName: String?
    let triggerPayload: String?
    let steps: [AdminAgentStudioRunStep]
    let ran: Int?
    let blocked: Int?
    let unconfigured: Int?
    let needsApproval: Int?
    let skipped: Int?
    let total: Int?
    let ready: Bool?
    let refused: Bool
    let truncated: Bool
    let blockers: [String]
    let narrative: String?
    let accuracy: Int?
    let durationMs: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let costEur: Double?
    let policyVersion: Int?

    init?(json: AriaJSON) {
        let outer = AdminAgentStudioFields(json)
        let fields = outer.object("run").isEmpty ? outer : outer.object("run")
        guard let id = fields.string("id", "runId") else { return nil }
        let summary = fields.object("summary")
        self.id = id
        workflowId = fields.string("workflowId")
        workflowName = fields.string("workflowName")
        mode = fields.string("mode")
        source = fields.string("source")
        status = fields.string("status", "state")
        agents = fields.strings("agents")
        startedAt = fields.date("startedAt")
        finishedAt = fields.date("finishedAt")
        startedBy = fields.string("startedBy")
        scenarioName = fields.string("scenarioName")
        triggerPayload = fields.string("triggerPayload")
        steps = fields.array("steps").compactMap(AdminAgentStudioRunStep.init(json:))
        ran = fields.int("ran") ?? summary.int("ran")
        blocked = fields.int("blocked") ?? summary.int("blocked")
        unconfigured = fields.int("unconfigured") ?? summary.int("unconfigured")
        needsApproval = fields.int("needsApproval") ?? summary.int("needsApproval")
        skipped = fields.int("skipped") ?? summary.int("skipped")
        total = fields.int("total") ?? summary.int("total")
        ready = fields.bool("ready") ?? summary.bool("ready")
        refused = fields.bool("refused") ?? false
        truncated = fields.bool("truncated") ?? false
        // Il messaggio di ogni blocco: quelli dettagliati se ci sono, la lista semplice se no.
        let detailed = (fields.array("blockerDetails") + summary.array("blockerDetails"))
            .compactMap { AdminAgentStudioFields($0).string("message") }
        let plain = fields.strings("blockers") + summary.strings("blockers")
        var seen = Set<String>()
        blockers = (detailed.isEmpty ? plain : detailed).filter { seen.insert($0).inserted }
        narrative = summary.string("narrative")
        accuracy = summary.int("accuracy")
        durationMs = summary.int("durationMs")
        let tokens = fields.object("tokens").isEmpty ? summary.object("tokens") : fields.object("tokens")
        inputTokens = tokens.int("input")
        outputTokens = tokens.int("output")
        costEur = fields.double("costEur") ?? summary.double("costEur")
        policyVersion = fields.int("policyVersion") ?? summary.int("policyVersion")
    }

    /// In corso o fermo su un'approvazione: si può annullare e conviene seguirlo.
    var isActive: Bool {
        if let status { return AdminAgentStudioStatus.isActive(status) }
        return finishedAt == nil
    }
}

/// Il verdetto di un nodo (RunStepRecord).
nonisolated struct AdminAgentStudioRunStep: Sendable, Identifiable, Hashable {
    let id: String
    let nodeId: String
    let outcome: String
    let reason: String?
    let agentName: String?
    let connectorId: String?
    let iteration: Int?
    let output: String?
    let simulated: Bool
    let durationMs: Int?
    let costEur: Double?
    let model: String?
    let accuracyScore: Int?
    let grounded: Bool?
    /// L'approvazione su cui il passo è fermo (outcome `needs_approval`).
    let approvalId: String?

    init?(json: AriaJSON) {
        let fields = AdminAgentStudioFields(json)
        guard let nodeId = fields.string("nodeId", "id") else { return nil }
        self.nodeId = nodeId
        iteration = fields.int("iteration")
        id = iteration.map { "\(nodeId)#\($0)" } ?? nodeId
        outcome = fields.string("outcome", "status") ?? "unknown"
        reason = fields.string("reason", "message")
        agentName = fields.string("agentName")
        connectorId = fields.string("connectorId")
        output = fields.string("output")
        simulated = fields.bool("simulated") ?? false
        durationMs = fields.int("durationMs")
        costEur = fields.double("costEur")
        model = fields.string("model")
        let accuracy = fields.object("accuracy")
        accuracyScore = accuracy.int("score")
        grounded = accuracy.bool("grounded")
        approvalId = fields.string("approvalId")
    }

    /// Simulato, durata, costo, modello, accuratezza: solo quelli presenti, in una riga.
    var metricsLine: String? {
        var parts: [String] = []
        if simulated { parts.append(String(localized: "Simulated")) }
        if let durationMs {
            parts.append(Duration.milliseconds(durationMs)
                .formatted(.units(allowed: [.minutes, .seconds, .milliseconds], width: .narrow, maximumUnitCount: 2)))
        }
        if let costEur { parts.append(costEur.formatted(.currency(code: "EUR"))) }
        if let model { parts.append(model) }
        if let accuracyScore { parts.append(String(localized: "Accuracy \(accuracyScore)%")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
