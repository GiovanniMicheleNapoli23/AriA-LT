//
//  AdminAgentStudioWorkflowViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un workflow: passi in sola lettura (il grafo si modifica sulla web), attiva/disattiva,
//  avvio di un controllo, di una simulazione o di un run reale, e lo storico dei run.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioWorkflowViewModel {
    let backend: AriaBackend
    let workflowId: String

    private(set) var workflow: AdminAgentStudioWorkflow?
    private(set) var workflowError: String?
    private(set) var runs: [AdminAgentStudioRun] = []
    private(set) var runsError: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    private(set) var isTogglingEnabled = false
    /// La modalità del run partito dall'app e non ancora finito.
    private(set) var runningMode: AdminAgentStudioRunMode?
    private(set) var lastResult: AdminAgentStudioRunResult?
    /// Il run reale aspetta una conferma.
    var showsRunConfirmation = false
    var actionError: String?

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    @ObservationIgnored private let onWorkflowChanged: (AdminAgentStudioWorkflow) -> Void
    @ObservationIgnored private let onActivityChanged: () async -> Void

    init(backend: AriaBackend, workflowId: String, seed: AdminAgentStudioWorkflow?,
         onWorkflowChanged: @escaping (AdminAgentStudioWorkflow) -> Void,
         onActivityChanged: @escaping () async -> Void) {
        self.backend = backend
        self.workflowId = workflowId
        self.workflow = seed
        self.onWorkflowChanged = onWorkflowChanged
        self.onActivityChanged = onActivityChanged
    }

    // MARK: Caricamento

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await backend.api.call(AdminAgentStudioAPI.workflow(id: workflowId)).value
            workflow = fresh
            workflowError = nil
            onWorkflowChanged(fresh)
        } catch {
            workflowError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
        await loadRuns()
        hasLoaded = true
    }

    private func loadRuns() async {
        do {
            runs = try await backend.api.call(AdminAgentStudioAPI.runs(workflowId: workflowId)).items
            runsError = nil
        } catch {
            runsError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Scheda

    var title: String { workflow?.name ?? String(localized: "Workflow") }

    /// I nodi nell'ordine del grafo (dal trigger in giù); quelli in un ciclo o staccati in fondo.
    var steps: [AdminAgentStudioWorkflowStep] {
        guard let workflow else { return [] }
        let nodes = workflow.nodes.compactMap(AdminAgentStudioWorkflowStep.init(json:))
        var incoming = Dictionary(nodes.map { ($0.id, 0) }, uniquingKeysWith: { first, _ in first })
        var next: [String: [String]] = [:]
        for edge in workflow.edges {
            let fields = AdminAgentStudioFields(edge)
            guard let source = fields.string("source"), let target = fields.string("target"),
                  incoming[source] != nil, incoming[target] != nil else { continue }
            incoming[target, default: 0] += 1
            next[source, default: []].append(target)
        }
        var queue = nodes.map(\.id).filter { incoming[$0] == 0 }
        var order: [String] = []
        var seen = Set<String>()
        while !queue.isEmpty {
            let id = queue.removeFirst()
            guard seen.insert(id).inserted else { continue }
            order.append(id)
            for target in next[id] ?? [] {
                incoming[target, default: 0] -= 1
                if incoming[target] == 0 { queue.append(target) }
            }
        }
        let byId = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return order.compactMap { byId[$0] } + nodes.filter { !seen.contains($0.id) }
    }

    var fields: [AdminAssetField] {
        guard let workflow else { return [] }
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Status"), workflow.enabled ? String(localized: "Enabled") : String(localized: "Disabled"))
        add(String(localized: "Steps"), String(workflow.nodes.count))
        add(String(localized: "Runs today"), workflow.runsToday.map(String.init))
        add(String(localized: "Last run"), workflow.lastRunAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Updated"), workflow.updatedAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Created"), workflow.createdAt?.formatted(date: .abbreviated, time: .omitted))
        return rows
    }

    /// I più recenti in alto.
    var sortedRuns: [AdminAgentStudioRun] {
        runs.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    func subtitle(for run: AdminAgentStudioRun) -> String {
        var parts: [String] = []
        if let mode = run.mode { parts.append(AdminAgentStudioRunMode(rawValue: mode)?.label ?? mode) }
        if let ran = run.ran, let total = run.total, total > 0 { parts.append(String(localized: "\(ran) of \(total) ran")) }
        if let blocked = run.blocked, blocked > 0 { parts.append(String(localized: "\(blocked) blocked")) }
        return parts.joined(separator: " · ")
    }

    func footnote(for run: AdminAgentStudioRun) -> String? {
        run.startedAt?.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: Attiva / disattiva

    /// Per il Toggle: cambiarlo manda la richiesta; se il server rifiuta resta com'era.
    var isEnabled: Bool {
        get { workflow?.enabled ?? false }
        set { Task { await setEnabled(newValue) } }
    }

    func setEnabled(_ enabled: Bool) async {
        guard let workflow, workflow.enabled != enabled, !isTogglingEnabled else { return }
        isTogglingEnabled = true
        defer { isTogglingEnabled = false }
        do {
            let updated = try await backend.api.call(AdminAgentStudioAPI.setEnabled(workflowId: workflow.id, enabled)).value
            self.workflow = updated
            onWorkflowChanged(updated)
        } catch {
            actionError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Avvio

    var canStart: Bool { workflow != nil && runningMode == nil }

    /// Controllo e simulazione partono subito; il run reale chiede conferma.
    func choose(_ mode: AdminAgentStudioRunMode) async {
        if mode == .run {
            showsRunConfirmation = true
        } else {
            await start(mode)
        }
    }

    func start(_ mode: AdminAgentStudioRunMode) async {
        guard let workflow, runningMode == nil else { return }
        runningMode = mode
        defer { runningMode = nil }
        let body = AdminAgentStudioRunBody(workflowId: workflow.id, workflowName: workflow.name, mode: mode.rawValue,
                                           graph: workflow.graph, plantId: backend.activePlantId)
        do {
            let lines = try await AdminAgentStudioAPI.startRun(body, api: backend.api)
            lastResult = AdminAgentStudioRunResult(mode: mode, lines: lines)
        } catch let error as URLError where error.code == .timedOut {
            // Lo stream è rimasto muto troppo a lungo: il run continua sul server.
            actionError = String(localized: "This run is taking a while. It keeps going on the server: follow it under Active.")
        } catch {
            actionError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
        await loadRuns()
        await onActivityChanged()
    }

    /// "5 ran · 1 blocked": quanti eventi per esito, nell'ordine in cui compaiono.
    var lastResultSummary: String? {
        guard let lastResult else { return nil }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for status in lastResult.events.compactMap(\.status) {
            let label = AdminAgentStudioStatus.label(for: status)
            if counts[label] == nil { order.append(label) }
            counts[label, default: 0] += 1
        }
        guard !order.isEmpty else { return nil }
        return order.map { "\(counts[$0] ?? 0) \($0.lowercased())" }.joined(separator: " · ")
    }

    /// Il run appena partito, se compare nello storico.
    var lastResultRun: AdminAgentStudioRun? {
        guard let id = lastResult?.runId else { return nil }
        return runs.first { $0.id == id }
    }
}
