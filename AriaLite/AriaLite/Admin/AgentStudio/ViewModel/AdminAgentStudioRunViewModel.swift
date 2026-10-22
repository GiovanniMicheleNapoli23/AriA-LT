//
//  AdminAgentStudioRunViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un run: riassunto, verdetto di ogni nodo, blocchi e il registro degli eventi.
//  Finché il run è vivo si rilegge il record ogni pochi secondi (GET …/events resterebbe aperto
//  fino alla fine); il registro completo si chiede a run finito, o su richiesta. Un run vivo si può annullare.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioRunViewModel {
    let backend: AriaBackend
    let runId: String
    let workflowId: String?
    /// La riga dei run attivi da cui si è arrivati, finché non c'è il record.
    let activeSeed: AdminAgentStudioActiveRun?

    private(set) var run: AdminAgentStudioRun?
    private(set) var runError: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    private(set) var events: [AdminAgentStudioRunEvent] = []
    private(set) var eventsError: String?
    private(set) var isLoadingEvents = false
    private(set) var hasLoadedEvents = false

    private(set) var isCancelling = false
    private(set) var wasCancelled = false
    var showsCancelConfirmation = false
    var actionError: String?

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    @ObservationIgnored private let onActivityChanged: () async -> Void

    /// Ogni quanto si rilegge un run vivo.
    private static let pollInterval: Duration = .seconds(4)

    init(backend: AriaBackend, workflowId: String?, runId: String, activeSeed: AdminAgentStudioActiveRun?,
         onActivityChanged: @escaping () async -> Void) {
        self.backend = backend
        self.workflowId = workflowId
        self.runId = runId
        self.activeSeed = activeSeed
        self.onActivityChanged = onActivityChanged
    }

    // MARK: Caricamento

    /// Senza `workflowId` il record non si può leggere: resta la riga del run attivo e il registro.
    var canReadRecord: Bool { workflowId != nil }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        await loadRecord()
        hasLoaded = true
        if !isActive, !hasLoadedEvents { await loadEvents() }
    }

    private func loadRecord() async {
        guard let workflowId else { return }
        do {
            run = try await backend.api.call(AdminAgentStudioAPI.run(workflowId: workflowId, runId: runId)).value
            runError = nil
        } catch {
            guard let message = AdminAgentStudioFailure.message(for: error, backend: backend) else { return }
            runError = message
        }
    }

    /// Segue un run vivo: rilegge il record finché non finisce (la vista lo lega al suo `.task`).
    func follow() async {
        guard canReadRecord else { return }
        while isActive, !Task.isCancelled {
            try? await Task.sleep(for: Self.pollInterval)
            guard !Task.isCancelled else { return }
            await loadRecord()
        }
        if hasLoaded, !hasLoadedEvents { await loadEvents() }
    }

    /// Il registro degli eventi. Per un run vivo la risposta arriva solo a run finito.
    func loadEvents() async {
        guard !isLoadingEvents else { return }
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            let lines = try await AdminAgentStudioAPI.runEvents(runId: runId, api: backend.api)
            events = AdminAgentStudioRunStream.events(from: lines)
            eventsError = nil
            hasLoadedEvents = true
        } catch {
            eventsError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }

    // MARK: Stato

    var title: String {
        run?.workflowName ?? activeSeed?.workflowName ?? String(localized: "Run")
    }

    var status: String? {
        if wasCancelled, run?.isActive ?? true { return "cancelled" }
        return run?.status ?? activeSeed?.status
    }

    var isActive: Bool {
        if wasCancelled { return false }
        if let run { return run.isActive }
        return activeSeed != nil
    }

    /// Il registro si può chiedere anche a run vivo, ma resta in attesa fino alla fine.
    var eventsWaitUntilFinished: Bool { isActive }

    var fields: [AdminAssetField] {
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        let mode = run?.mode ?? activeSeed?.mode
        add(String(localized: "Mode"), mode.flatMap { AdminAgentStudioRunMode(rawValue: $0)?.label } ?? mode)
        add(String(localized: "Source"), run?.source)
        add(String(localized: "Started"), (run?.startedAt ?? activeSeed?.startedAt)?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Finished"), run?.finishedAt?.formatted(date: .abbreviated, time: .shortened))
        add(String(localized: "Duration"), durationText)
        add(String(localized: "Started by"), run?.startedBy ?? activeSeed?.startedBy)
        add(String(localized: "Waiting for"), isActive ? activeSeed?.waitingFor : nil)
        add(String(localized: "Scenario"), run?.scenarioName)
        add(String(localized: "Agents"), run.map { $0.agents.joined(separator: ", ") })
        if let input = run?.inputTokens, let output = run?.outputTokens {
            add(String(localized: "Tokens"), String(localized: "\(input) in · \(output) out"))
        }
        add(String(localized: "Cost"), run?.costEur.map { $0.formatted(.currency(code: "EUR")) })
        add(String(localized: "Accuracy"), run?.accuracy.map { "\($0)%" })
        add(String(localized: "Policy version"), run?.policyVersion.map(String.init))
        add(String(localized: "Run ID"), runId)
        return rows
    }

    private var durationText: String? {
        if let ms = run?.durationMs { return Duration.milliseconds(ms).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated)) }
        guard let start = run?.startedAt, let end = run?.finishedAt, end >= start else { return nil }
        return Duration.seconds(end.timeIntervalSince(start))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }

    /// I contatori del riassunto che hanno un valore (per le tessere).
    var counters: [(title: String, value: Int, status: String)] {
        guard let run else { return [] }
        let all: [(String, Int?, String)] = [
            (String(localized: "Ran"), run.ran, "ran"),
            (String(localized: "Needs approval"), run.needsApproval, "needs_approval"),
            (String(localized: "Blocked"), run.blocked, "blocked"),
            (String(localized: "Not configured"), run.unconfigured, "unconfigured"),
            (String(localized: "Skipped"), run.skipped, "skipped"),
        ]
        return all.compactMap { title, value, status in value.map { (title, $0, status) } }
    }

    // MARK: Annulla

    var canCancel: Bool { isActive && !isCancelling }

    func cancel() async {
        guard canCancel else { return }
        isCancelling = true
        defer { isCancelling = false }
        do {
            _ = try await backend.api.call(AdminAgentStudioAPI.cancelRun(runId: runId))
            wasCancelled = true
            await loadRecord()
            await onActivityChanged()
        } catch {
            actionError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }
}
