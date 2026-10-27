//
//  AdminAgentStudioWorkflowViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un workflow: passi in sola lettura (il grafo si modifica sulla web), attiva/disattiva,
//  avvio di un controllo, di una simulazione o di un run reale, e lo storico dei run.
//  Testi già pronti per la schermata (stato, tempi, titoli) in AdminAgentStudioWorkflowViewModel+Display.
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
    /// La modalità scelta in "Run it".
    var selectedMode: AdminAgentStudioRunMode = .simulate
    /// Il run appena avviato: la vista lo apre subito.
    private(set) var launchedRun: AdminAgentStudioRunViewModel?
    /// Il run reale aspetta una conferma.
    var showsRunConfirmation = false
    var actionError: String?
    /// "Show all" nei run recenti: sì = tutto lo storico, no = gli ultimi cinque.
    private(set) var showsAllRuns = false

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    @ObservationIgnored private let onWorkflowChanged: (AdminAgentStudioWorkflow) -> Void
    /// Crea (e tiene vivo altrove) il run; la chiusura passata si chiama quando cambia, per lo storico.
    typealias Launch = (AdminAgentStudioRunBody, AdminAgentStudioRunMode, [AdminAgentStudioWorkflowStep],
                        @escaping () async -> Void) -> AdminAgentStudioRunViewModel?
    @ObservationIgnored private let onLaunch: Launch

    init(backend: AriaBackend, workflowId: String, seed: AdminAgentStudioWorkflow?,
         onWorkflowChanged: @escaping (AdminAgentStudioWorkflow) -> Void,
         onLaunch: @escaping Launch) {
        self.backend = backend
        self.workflowId = workflowId
        self.workflow = seed
        self.onWorkflowChanged = onWorkflowChanged
        self.onLaunch = onLaunch
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
        workflow.map(AdminAgentStudioWorkflowStep.ordered(in:)) ?? []
    }

    var fields: [AdminAssetField] {
        guard let workflow else { return [] }
        var rows: [AdminAssetField] = []
        func add(_ title: String, _ value: String?) {
            if let value, !value.isEmpty { rows.append(AdminAssetField(title: title, value: value)) }
        }
        add(String(localized: "Status"), workflow.enabled ? String(localized: "Enabled") : String(localized: "Paused"))
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

    func showAllRuns() { showsAllRuns = true }

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

    var canStart: Bool { workflow != nil }

    /// Per `navigationDestination(isPresented:)`: tornando indietro il run resta vivo nel registro.
    var showsLaunchedRun: Bool {
        get { launchedRun != nil }
        set { if !newValue { launchedRun = nil } }
    }

    /// Controllo e simulazione partono subito; il run reale chiede conferma.
    func choose(_ mode: AdminAgentStudioRunMode) async {
        if mode == .run {
            showsRunConfirmation = true
        } else {
            await start(mode)
        }
    }

    func start(_ mode: AdminAgentStudioRunMode) async {
        guard let workflow else { return }
        let body = AdminAgentStudioRunBody(workflowId: workflow.id, workflowName: workflow.name, mode: mode.rawValue,
                                           graph: workflow.graph, plantId: backend.activePlantId)
        // Il run avvisa da sé quando parte e quando finisce: lì si rileggono attivi e storico.
        launchedRun = onLaunch(body, mode, steps) { [weak self] in await self?.loadRuns() }
    }
}
