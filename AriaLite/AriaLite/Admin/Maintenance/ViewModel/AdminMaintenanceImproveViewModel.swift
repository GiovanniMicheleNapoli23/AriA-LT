//
//  AdminMaintenanceImproveViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" di un piano (POST /v1/maintenance-plans/{plan_id}/ai-improve): si sceglie cosa chiedere,
//  il server propone, l'utente decide cosa applicare (PATCH del piano con le sole parti scelte).
//  Un'azione che il server non conosce torna come {"status": "error"}: si mostra come errore, non come proposta;
//  se il server rifiuta un valore con 400/422 e dice quelli validi, si può riprovare con uno di quelli.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMaintenanceImproveViewModel: Identifiable {
    let backend: AriaBackend
    private(set) var plan: AdminMaintenancePlan
    private let onApplied: (AdminMaintenancePlan) -> Void

    var customPrompt = ""
    /// La lingua in cui tradurre (codice ISO, fra `AdminAIImproveStatus.translationLanguages`).
    var translateLanguage = AdminAIImproveStatus.defaultTranslationLanguage
    /// Il passo (indice) da riscrivere con "Improve one step".
    private(set) var stepIndex = 0

    private(set) var isRunning = false
    /// Il valore di `action` dell'ultima richiesta.
    private(set) var lastAction: String?
    private(set) var proposal: AdminMaintenanceProposal?
    private(set) var failure: AdminWorkOrderAssistantFailure?

    /// Le parti della proposta da applicare.
    var applyTasks = true
    var applyParts = true
    var applyDescription = true
    var applyDuration = true
    private(set) var isApplying = false
    private(set) var applyError: String?
    /// L'avviso "Applied" in alto: compare dopo un'applicazione riuscita e se ne va da solo.
    private(set) var showsApplied = false
    @ObservationIgnored private var appliedTask: Task<Void, Never>?

    @ObservationIgnored private var task: Task<Void, Never>?
    /// Il passo chiesto con "Improve one step": una proposta di un solo passo lo sostituisce, non cancella gli altri.
    @ObservationIgnored private var askedStepIndex: Int?

    init(backend: AriaBackend, plan: AdminMaintenancePlan, onApplied: @escaping (AdminMaintenancePlan) -> Void) {
        self.backend = backend
        self.plan = plan
        self.onApplied = onApplied
    }

    var canAskCustom: Bool { !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRunning }

    /// Le lingue offerte per la traduzione, col nome da mostrare.
    var translationLanguages: [(code: String, name: String)] {
        AdminAIImproveStatus.translationLanguages.map { ($0, AdminAIImproveStatus.languageName($0)) }
    }

    /// Un passo, per il menu di "Improve one step".
    func stepLabel(_ index: Int) -> String {
        "\(index + 1). \(plan.tasks[index])"
    }

    /// La richiesta in corso è questa: la sua riga mostra la rotella.
    func isRunning(_ action: AdminMaintenanceImproveAction) -> Bool {
        isRunning && lastAction == action.rawValue
    }

    /// La richiesta in corso è uno dei valori validi indicati dal server.
    func isRunning(rawAction: String) -> Bool {
        isRunning && lastAction == rawAction
    }

    // MARK: Richiesta

    func run(_ action: AdminMaintenanceImproveAction) {
        start(action.rawValue, action: action)
    }

    /// "Improve one step" sul passo scelto nel menu.
    func improveStep(at index: Int) {
        guard plan.tasks.indices.contains(index), !isRunning else { return }
        stepIndex = index
        run(.improveStep)
    }

    /// "Translate" nella lingua scelta nel menu.
    func translate(to language: String) {
        guard !isRunning else { return }
        translateLanguage = language
        run(.translate)
    }

    /// Riprova con uno dei valori che il server ha detto validi.
    func retry(with rawAction: String) {
        start(rawAction, action: .improveAll)
    }

    private func start(_ rawAction: String, action: AdminMaintenanceImproveAction) {
        guard !isRunning else { return }
        task?.cancel()
        task = Task { await ask(rawAction, action: action) }
    }

    private func ask(_ rawAction: String, action: AdminMaintenanceImproveAction) async {
        guard let id = plan.serverId else { return }
        isRunning = true
        failure = nil
        applyError = nil
        lastAction = rawAction
        askedStepIndex = action == .improveStep ? stepIndex : nil
        defer { isRunning = false }
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = AdminMaintenanceImproveRequest(
            action: rawAction,
            stepIndex: action == .improveStep ? stepIndex : nil,
            customPrompt: action == .custom && !prompt.isEmpty ? prompt : nil,
            language: action == .translate ? translateLanguage : Locale.current.language.languageCode?.identifier)
        do {
            let json = try await backend.api.call(AdminMaintenanceAPI.aiImprove(id: id, body))
            guard !Task.isCancelled else { return }
            if let message = AdminAIImproveStatus.errorMessage(in: json) {
                proposal = nil
                failure = AdminWorkOrderAssistantFailure(message: message, validActions: [])
                return
            }
            if action == .custom { customPrompt = "" }
            let result = AdminMaintenanceProposal(json: json)
            if result.isEmpty {
                proposal = nil
                failure = AdminWorkOrderAssistantFailure(message: String(localized: "The assistant didn't suggest any change."),
                                                         validActions: [])
            } else {
                proposal = result
                resetApplyChoices(for: result)
            }
        } catch {
            guard let found = AdminWorkOrderAIFailure.failure(for: error, action: rawAction, backend: backend) else { return }
            proposal = nil
            failure = found
        }
    }

    private func resetApplyChoices(for proposal: AdminMaintenanceProposal) {
        applyTasks = !proposal.tasks.isEmpty
        applyParts = !proposal.spareParts.isEmpty
        applyDescription = proposal.description != nil
        applyDuration = proposal.estimatedDurationMin != nil
    }

    // MARK: Applicare

    /// Cosa cambierebbe: le parti proposte e spuntate.
    var canApply: Bool {
        guard let proposal, plan.serverId != nil, !isApplying else { return false }
        return (applyTasks && !proposal.tasks.isEmpty) || (applyParts && !proposal.spareParts.isEmpty)
            || (applyDescription && proposal.description != nil) || (applyDuration && proposal.estimatedDurationMin != nil)
    }

    func apply() async {
        guard canApply, let proposal, let id = plan.serverId else { return }
        isApplying = true
        applyError = nil
        defer { isApplying = false }
        var changes = AdminPatchBody()
        if applyTasks, !proposal.tasks.isEmpty {
            var tasks = proposal.tasks
            if let index = askedStepIndex, tasks.count == 1, plan.tasks.indices.contains(index) {
                tasks = plan.tasks
                tasks[index] = proposal.tasks[0]
            }
            changes.value("tasks", .array(tasks.map(AriaJSON.string)), was: .array(plan.tasks.map(AriaJSON.string)))
        }
        if applyParts, !proposal.spareParts.isEmpty {
            changes.value("spare_parts", .array(proposal.spareParts.map(AriaJSON.string)),
                          was: .array(plan.spareParts.map(AriaJSON.string)))
        }
        if applyDescription, let text = proposal.description { changes.text("description", text, was: plan.description) }
        if applyDuration, let minutes = proposal.estimatedDurationMin {
            changes.number("estimated_duration_min", Double(minutes), was: plan.estimatedDurationMin.map(Double.init))
        }
        guard !changes.isEmpty else {
            // La proposta coincide col piano: niente da scrivere.
            finishApplying()
            return
        }
        do {
            let saved = try await backend.api.call(AdminMaintenanceAPI.update(id: id, changes))
            plan = saved
            onApplied(saved)
            finishApplying()
        } catch {
            applyError = AdminMaintenanceFailure.message(for: error, backend: backend)
        }
    }

    /// Scarta la proposta: il piano resta com'è.
    func discard() {
        proposal = nil
        failure = nil
        applyError = nil
    }

    /// Applicato: si torna alle richieste e in alto compare l'avviso, che sparisce da solo.
    private func finishApplying() {
        proposal = nil
        failure = nil
        applyError = nil
        showsApplied = true
        appliedTask?.cancel()
        appliedTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            self?.showsApplied = false
        }
    }

    /// Alla chiusura del foglio: la richiesta in corso non serve più.
    func cancel() {
        task?.cancel()
        task = nil
        appliedTask?.cancel()
    }
}
