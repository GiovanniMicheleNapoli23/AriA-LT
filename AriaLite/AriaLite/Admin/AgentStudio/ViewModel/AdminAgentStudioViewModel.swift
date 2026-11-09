//
//  AdminAgentStudioViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La sezione Agent Studio, come la pagina /agent-studio della web: workflow, approvazioni, run attivi,
//  policy, notifiche e accuratezza degli agenti. Vive in AppViewModel: i dati restano fra un cambio di sezione
//  e l'altro. Ogni blocco si carica per conto suo: se uno fallisce (o il ruolo non lo vede) gli altri restano.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioViewModel {
    let backend: AriaBackend
    /// I prompt degli agenti: lista ed editor condividono lo stesso stato.
    let prompts: AdminAgentStudioPromptsViewModel

    private(set) var workflows: [AdminAgentStudioWorkflow] = []
    private(set) var workflowsError: String?
    private(set) var activeRuns: [AdminAgentStudioActiveRun] = []
    private(set) var activeRunsError: String?
    private(set) var pendingApprovals: [AdminAgentStudioApproval] = []
    private(set) var pendingApprovalsError: String?
    private(set) var notifications: [AdminAgentStudioNotification] = []
    private(set) var notificationsError: String?
    private(set) var accuracy: [AdminAgentStudioAgentAccuracy] = []
    private(set) var accuracyWindow: Int?
    private(set) var accuracyError: String?
    private(set) var policy: AdminAgentStudioPolicy?
    private(set) var policyError: String?

    /// Le approvazioni di uno stato diverso da "pending" (quelle in attesa sono già in `pendingApprovals`).
    var approvalFilter: AdminAgentStudioApprovalFilter = .pending
    private(set) var filteredApprovals: [AdminAgentStudioApproval] = []
    private(set) var filteredApprovalsError: String?
    private(set) var isLoadingApprovals = false
    private(set) var hasLoadedApprovals = false
    @ObservationIgnored private var loadedApprovalsKey: String?

    var showsUnreadOnly = false

    /// I run avviati dall'app, vivi finché non finiscono anche fuori dalla loro schermata.
    @ObservationIgnored private var launches: [AdminAgentStudioRunViewModel] = []

    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var lastUpdated: Date?
    @ObservationIgnored private var loadedKey: String?

    /// Errore di un'azione veloce (segna come letta): si mostra in un avviso.
    var actionError: String?

    var showsActionError: Bool {
        get { actionError != nil }
        set { if !newValue { actionError = nil } }
    }

    init(backend: AriaBackend) {
        self.backend = backend
        prompts = AdminAgentStudioPromptsViewModel(backend: backend)
    }

    /// Cambia quando va ricaricato tutto: l'azienda attiva.
    var loadKey: String { backend.activeCompanyId ?? "-" }

    /// Cambia quando va richiesta la lista delle approvazioni filtrate.
    var approvalsKey: String { "\(loadKey)|\(approvalFilter.rawValue)" }

    // MARK: Caricamento

    func load() async {
        let key = loadKey
        // Altra azienda: i dati vecchi non valgono, non si mostrano mentre arrivano i nuovi.
        if key != loadedKey {
            clearData()
            loadedKey = key
        }
        isLoading = true
        defer { isLoading = false }
        let api = backend.api
        async let workflowsResult = Self.fetch(AdminAgentStudioAPI.workflows(), api: api)
        async let activeResult = Self.fetch(AdminAgentStudioAPI.activeRuns(), api: api)
        async let pendingResult = Self.fetch(AdminAgentStudioAPI.approvals(status: "pending"), api: api)
        async let notificationsResult = Self.fetch(AdminAgentStudioAPI.notifications(), api: api)
        async let accuracyResult = Self.fetch(AdminAgentStudioAPI.agentAccuracy(), api: api)
        async let policyResult = Self.fetch(AdminAgentStudioAPI.policy(), api: api)
        let results = await (workflowsResult, activeResult, pendingResult, notificationsResult, accuracyResult, policyResult)
        guard key == loadKey, !Task.isCancelled else { return }

        if case .success(let list) = results.0 { workflows = list.items }
        workflowsError = message(results.0)
        if case .success(let list) = results.1 { activeRuns = list.items }
        activeRunsError = message(results.1)
        if case .success(let list) = results.2 { pendingApprovals = list.items }
        pendingApprovalsError = message(results.2)
        if case .success(let list) = results.3 { notifications = list.items }
        notificationsError = message(results.3)
        if case .success(let list) = results.4 {
            accuracy = list.items.sorted { $0.agent.localizedStandardCompare($1.agent) == .orderedAscending }
            accuracyWindow = list.fields.int("window")
        }
        accuracyError = message(results.4)
        if case .success(let one) = results.5 { policy = one.value }
        policyError = message(results.5)

        hasLoaded = true
        lastUpdated = .now
    }

    /// Dopo un'azione in un dettaglio (run avviato o annullato, approvazione decisa): run e approvazioni.
    func refreshActivity() async {
        let api = backend.api
        async let activeResult = Self.fetch(AdminAgentStudioAPI.activeRuns(), api: api)
        async let pendingResult = Self.fetch(AdminAgentStudioAPI.approvals(status: "pending"), api: api)
        let (active, pending) = await (activeResult, pendingResult)
        if case .success(let list) = active { activeRuns = list.items }
        activeRunsError = message(active)
        if case .success(let list) = pending { pendingApprovals = list.items }
        pendingApprovalsError = message(pending)
        if approvalFilter != .pending { await loadApprovals(force: true) }
    }

    /// La lista di uno stato diverso da "pending" (quella la carica già `load`).
    func loadApprovals(force: Bool = false) async {
        guard approvalFilter != .pending else { return }
        let key = approvalsKey
        if key != loadedApprovalsKey {
            filteredApprovals = []
            hasLoadedApprovals = false
            filteredApprovalsError = nil
            loadedApprovalsKey = key
        } else if hasLoadedApprovals, !force {
            return
        }
        let filter = approvalFilter
        isLoadingApprovals = true
        defer { isLoadingApprovals = false }
        let result = await Self.fetch(AdminAgentStudioAPI.approvals(status: filter.query), api: backend.api)
        guard filter == approvalFilter, key == approvalsKey else { return }
        if case .success(let list) = result {
            filteredApprovals = list.items
            hasLoadedApprovals = true
        }
        filteredApprovalsError = message(result)
    }

    private nonisolated static func fetch<T: Decodable & Sendable>(_ endpoint: AriaEndpoint<T>, api: AriaAPIClient) async -> Result<T, any Error> {
        do { return .success(try await api.call(endpoint)) } catch { return .failure(error) }
    }

    private func message<T>(_ result: Result<T, any Error>) -> String? {
        guard case .failure(let error) = result else { return nil }
        return AdminAgentStudioFailure.message(for: error, backend: backend)
    }

    // MARK: Workflow

    /// Attivi prima, poi per nome.
    var sortedWorkflows: [AdminAgentStudioWorkflow] {
        workflows.sorted {
            if $0.enabled != $1.enabled { return $0.enabled }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var enabledCount: Int { workflows.count { $0.enabled } }

    var runsTodayCount: Int { workflows.reduce(0) { $0 + ($1.runsToday ?? 0) } }

    /// Un workflow cambiato nel dettaglio (attivato, disattivato): si aggiorna la lista senza ricaricarla.
    func apply(_ workflow: AdminAgentStudioWorkflow) {
        if let index = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[index] = workflow
        } else {
            workflows.append(workflow)
        }
    }

    // MARK: Approvazioni

    var visibleApprovals: [AdminAgentStudioApproval] {
        let list = approvalFilter == .pending ? pendingApprovals : filteredApprovals
        return list.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var approvalsError: String? {
        approvalFilter == .pending ? pendingApprovalsError : filteredApprovalsError
    }

    var approvalsLoaded: Bool {
        approvalFilter == .pending ? hasLoaded : hasLoadedApprovals
    }

    // MARK: Notifiche

    var unreadCount: Int { notifications.count { !$0.isRead } }

    var visibleNotifications: [AdminAgentStudioNotification] {
        notifications
            .filter { !showsUnreadOnly || !$0.isRead }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    /// Segnata subito qui; se il server rifiuta torna non letta.
    func markRead(_ notification: AdminAgentStudioNotification) async {
        guard !notification.isRead, let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
        do {
            _ = try await backend.api.call(AdminAgentStudioAPI.markRead(notificationId: notification.id))
        } catch {
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) { notifications[index].isRead = false }
            actionError = AdminAgentStudioFailure.message(for: error, backend: backend)
        }
    }

    func markAllRead() async {
        for notification in notifications where !notification.isRead {
            await markRead(notification)
            if actionError != nil { return }
        }
    }

    /// Dove porta una notifica: l'approvazione o il run a cui si riferisce.
    func route(for notification: AdminAgentStudioNotification) -> AdminAgentStudioRoute? {
        if let approvalId = notification.approvalId { return .approval(id: approvalId) }
        if let runId = notification.runId { return .run(workflowId: notification.workflowId, runId: runId) }
        if let workflowId = notification.workflowId { return .workflow(id: workflowId) }
        return nil
    }

    // MARK: Policy

    func policySaved(_ saved: AdminAgentStudioPolicy) {
        policy = saved
        policyError = nil
    }

    // MARK: Dettagli

    func makeWorkflowViewModel(id: String) -> AdminAgentStudioWorkflowViewModel {
        AdminAgentStudioWorkflowViewModel(
            backend: backend, workflowId: id, seed: workflows.first { $0.id == id },
            onWorkflowChanged: { [weak self] in self?.apply($0) },
            onLaunch: { [weak self] body, mode, steps, onEnded in
                self?.launch(body, mode: mode, steps: steps, onEnded: onEnded)
            }
        )
    }

    /// Un run avviato dall'app: resta qui (e continua a seguire lo stream) anche se si torna indietro.
    private func launch(_ body: AdminAgentStudioRunBody, mode: AdminAgentStudioRunMode,
                        steps: [AdminAgentStudioWorkflowStep],
                        onEnded: @escaping () async -> Void) -> AdminAgentStudioRunViewModel {
        launches.removeAll { !$0.isActive }
        let run = AdminAgentStudioRunViewModel(
            backend: backend, source: .start(body, mode: mode), workflowSteps: steps,
            onActivityChanged: { [weak self] in
                await self?.refreshActivity()
                await onEnded()
            }
        )
        launches.append(run)
        return run
    }

    /// Dal workflow già in lista: il dettaglio la aggiorna a ogni caricamento.
    func makeCanvasViewModel(workflowId: String) -> AdminAgentStudioCanvasViewModel? {
        workflows.first { $0.id == workflowId }.map(AdminAgentStudioCanvasViewModel.init(workflow:))
    }

    /// Un run partito da qui si riprende com'è; gli altri si seguono dal registro degli eventi.
    func makeRunViewModel(workflowId: String?, runId: String) -> AdminAgentStudioRunViewModel {
        if let launched = launches.first(where: { $0.runId == runId }) { return launched }
        let active = activeRuns.first { $0.id == runId }
        let workflowId = workflowId ?? active?.workflowId
        return AdminAgentStudioRunViewModel(
            backend: backend, source: .attach(runId: runId), workflowId: workflowId,
            workflowName: active?.workflowName ?? workflows.first { $0.id == workflowId }?.name,
            onActivityChanged: { [weak self] in await self?.refreshActivity() }
        )
    }

    func makeApprovalViewModel(id: String) -> AdminAgentStudioApprovalViewModel {
        let seed = (pendingApprovals + filteredApprovals).first { $0.id == id }
        return AdminAgentStudioApprovalViewModel(
            backend: backend, approvalId: id, seed: seed,
            onDecided: { [weak self] in await self?.refreshActivity() }
        )
    }

    func makePolicyFormViewModel() -> AdminAgentStudioPolicyFormViewModel? {
        guard let policy else { return nil }
        return AdminAgentStudioPolicyFormViewModel(backend: backend, policy: policy)
    }

    // MARK: Uscita

    private func clearData() {
        workflows = []
        workflowsError = nil
        activeRuns = []
        activeRunsError = nil
        pendingApprovals = []
        pendingApprovalsError = nil
        notifications = []
        notificationsError = nil
        accuracy = []
        accuracyWindow = nil
        accuracyError = nil
        policy = nil
        policyError = nil
        filteredApprovals = []
        filteredApprovalsError = nil
        hasLoadedApprovals = false
        loadedApprovalsKey = nil
        hasLoaded = false
        lastUpdated = nil
    }

    /// All'uscita dall'account: non resta niente dell'azienda precedente.
    func reset() {
        clearData()
        loadedKey = nil
        isLoading = false
        isLoadingApprovals = false
        actionError = nil
        approvalFilter = .pending
        showsUnreadOnly = false
        prompts.reset()
        launches.removeAll()
    }
}
