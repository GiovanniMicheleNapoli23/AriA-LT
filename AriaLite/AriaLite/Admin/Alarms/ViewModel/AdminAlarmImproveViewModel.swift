//
//  AdminAlarmImproveViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  "Improve with AI" di un allarme (POST /v1/alarms/{id}/ai-improve): si sceglie cosa chiedere, il server
//  propone, l'utente decide cosa applicare (PATCH dell'allarme con i soli campi scelti) o scarta.
//  Un'azione che il server non conosce torna come {"status": "error"}: si mostra come errore, non come proposta.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAlarmImproveViewModel: Identifiable {
    private(set) var alarm: AdminAlarm
    private let backend: AriaBackend
    private let onApplied: (AdminAlarm) -> Void

    var customPrompt = ""
    /// La lingua in cui tradurre (codice ISO, fra `AdminAIImproveStatus.translationLanguages`).
    var translateLanguage = AdminAIImproveStatus.defaultTranslationLanguage

    /// L'azione in corso (valore mandato al server): una alla volta.
    private(set) var runningAction: String?
    private(set) var proposal: AdminAlarmProposal?
    private(set) var failure: AdminAlarmAssistFailure?
    /// I campi della proposta da applicare.
    var selected: Set<AdminAlarmField> = []
    private(set) var isApplying = false
    private(set) var applyError: String?
    /// L'avviso "Applied" in alto: compare dopo un'applicazione riuscita e se ne va da solo.
    private(set) var showsApplied = false
    @ObservationIgnored private var appliedTask: Task<Void, Never>?

    @ObservationIgnored private var task: Task<Void, Never>?

    init(alarm: AdminAlarm, backend: AriaBackend, onApplied: @escaping (AdminAlarm) -> Void) {
        self.alarm = alarm
        self.backend = backend
        self.onApplied = onApplied
    }

    var isRunning: Bool { runningAction != nil }

    func isRunning(_ action: AdminAlarmImproveAction) -> Bool { runningAction == action.rawValue }

    var canAskCustom: Bool { !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRunning }

    // MARK: Richiesta

    func run(_ action: AdminAlarmImproveAction) {
        start(action.rawValue, isCustom: action == .custom)
    }

    /// "Translate" nella lingua scelta nel menu.
    func translate(to language: String) {
        guard !isRunning else { return }
        translateLanguage = language
        run(.translate)
    }

    /// Le lingue offerte per la traduzione, col nome da mostrare.
    var translationLanguages: [(code: String, name: String)] {
        AdminAIImproveStatus.translationLanguages.map { ($0, AdminAIImproveStatus.languageName($0)) }
    }

    /// Riprova con uno dei valori che il server ha detto validi.
    func retry(with rawAction: String) {
        start(rawAction, isCustom: false)
    }

    private func start(_ rawAction: String, isCustom: Bool) {
        guard !isRunning else { return }
        task?.cancel()
        // Subito, non nel task: un secondo tocco prima che parta non manda un'altra richiesta.
        runningAction = rawAction
        task = Task { await ask(rawAction, isCustom: isCustom) }
    }

    private func ask(_ rawAction: String, isCustom: Bool) async {
        failure = nil
        applyError = nil
        defer { runningAction = nil }
        let prompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let isTranslation = rawAction == AdminAlarmImproveAction.translate.rawValue
        let body = AdminAlarmImproveRequest(action: rawAction,
                                            customPrompt: isCustom && !prompt.isEmpty ? prompt : nil,
                                            language: isTranslation ? translateLanguage
                                                : Locale.current.language.languageCode?.identifier)
        do {
            let json = try await AdminAlarmsAPI(api: backend.api).improve(id: alarm.id, body)
            guard !Task.isCancelled else { return }
            if let message = AdminAIImproveStatus.errorMessage(in: json) {
                proposal = nil
                failure = AdminAlarmAssistFailure(message: message, validActions: [])
                return
            }
            if isCustom { customPrompt = "" }
            let result = AdminAlarmProposal(json: json, alarm: alarm)
            if result.isEmpty {
                proposal = nil
                let message = String(localized: "The assistant didn't suggest any change.")
                failure = AdminAlarmAssistFailure(message: message, validActions: [])
            } else {
                proposal = result
                selected = Set(result.changes.map(\.field))
            }
        } catch {
            guard let found = AdminAlarmAssistFailure.from(error, action: rawAction, backend: backend) else { return }
            proposal = nil
            failure = found
        }
    }

    // MARK: Applicare

    var canApply: Bool {
        guard let proposal, !isApplying else { return false }
        return proposal.changes.contains { selected.contains($0.field) }
    }

    /// Scarta la proposta: l'allarme resta com'è.
    func discard() {
        proposal = nil
        failure = nil
        applyError = nil
    }

    func apply() async {
        guard canApply, let proposal else { return }
        isApplying = true
        applyError = nil
        defer { isApplying = false }
        var update = AdminAlarmUpdate()
        for change in proposal.changes where selected.contains(change.field) {
            let text = change.proposed.joined(separator: "\n")
            switch change.field {
            case .description: update.description = .some(text)
            case .category: update.category = .some(text)
            case .zone: update.zone = .some(text)
            case .hmiPage: update.hmiPage = .some(text)
            case .typicalCauses: update.typicalCauses = .some(change.proposed)
            case .resolutionSteps: update.resolutionSteps = .some(change.proposed)
            }
        }
        do {
            let saved = try await AdminAlarmsAPI(api: backend.api).update(id: alarm.id, update)
            alarm = saved
            onApplied(saved)
            finishApplying()
        } catch {
            if let failure = AdminAlarmsFailure.from(error, action: .write, backend: backend) {
                applyError = failure.message
            }
        }
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
