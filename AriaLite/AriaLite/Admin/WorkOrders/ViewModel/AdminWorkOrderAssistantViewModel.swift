//
//  AdminWorkOrderAssistantViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'assistente AI di un ordine (POST /v1/work-orders/{id}/ai-assist).
//  Le scorciatoie e il prompt libero mandano un'azione; ogni risposta entra nella cronologia della
//  sessione. I valori proposti si scrivono sull'ordine con PATCH solo quando l'utente tocca "Apply".
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderAssistantViewModel: Identifiable {
    private(set) var order: AdminWorkOrder
    let backend: AriaBackend
    /// Un suggerimento applicato all'ordine (PATCH): il dettaglio e la lista si aggiornano.
    private let onUpdated: (AdminWorkOrder) -> Void

    var customPrompt = ""
    /// L'azione in corso (valore mandato al server): una alla volta.
    private(set) var runningAction: String?
    /// Le risposte di questa sessione, la più recente in cima.
    private(set) var entries: [AdminWorkOrderAssistantEntry] = []
    private(set) var failure: AdminWorkOrderAssistantFailure?
    /// La risposta che si sta scrivendo sull'ordine.
    private(set) var applyingEntryId: UUID?
    private(set) var applyError: String?

    init(order: AdminWorkOrder, backend: AriaBackend, onUpdated: @escaping (AdminWorkOrder) -> Void) {
        self.order = order
        self.backend = backend
        self.onUpdated = onUpdated
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    // MARK: Stato per la vista

    var quickActions: [AdminWorkOrderAIAction] { AdminWorkOrderAIAction.assistActions }

    var isRunning: Bool { runningAction != nil }

    func isRunning(_ action: AdminWorkOrderAIAction) -> Bool { runningAction == action.rawValue }

    var trimmedPrompt: String { customPrompt.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSendPrompt: Bool { !trimmedPrompt.isEmpty && !isRunning }

    /// Il prompt libero sta aspettando la risposta.
    var isSendingPrompt: Bool { runningAction == AdminWorkOrderAIAction.custom.rawValue }

    var isApplying: Bool { applyingEntryId != nil }

    // MARK: Domande

    func run(_ action: AdminWorkOrderAIAction) async {
        await perform(action: action.rawValue, title: action.title, systemImage: action.systemImage, prompt: nil)
    }

    func sendPrompt() async {
        guard canSendPrompt else { return }
        let prompt = trimmedPrompt
        let custom = AdminWorkOrderAIAction.custom
        if await perform(action: custom.rawValue, title: custom.title, systemImage: custom.systemImage, prompt: prompt) {
            customPrompt = ""
        }
    }

    /// Un valore di `action` che il server ha elencato come valido dopo un rifiuto.
    func runServerAction(_ action: String) async {
        let prompt = trimmedPrompt.isEmpty ? nil : trimmedPrompt
        await perform(action: action, title: action, systemImage: "text.bubble", prompt: prompt)
    }

    @discardableResult
    private func perform(action: String, title: String, systemImage: String, prompt: String?) async -> Bool {
        guard runningAction == nil else { return false }
        runningAction = action
        failure = nil
        defer { runningAction = nil }
        do {
            let json = try await api.aiAssist(order.id, AdminWorkOrderAIAssistRequest(action: action, customPrompt: prompt))
            var answer = AdminWorkOrderAIAnswer(json: json)
            if answer.isEmpty { answer = AdminWorkOrderAIAnswer(text: String(localized: "The assistant returned an empty answer.")) }
            entries.insert(AdminWorkOrderAssistantEntry(action: action, title: title, systemImage: systemImage,
                                                        prompt: prompt, answer: answer), at: 0)
            return true
        } catch {
            failure = AdminWorkOrderAIFailure.failure(for: error, action: action, backend: backend)
            return false
        }
    }

    func dismissFailure() { failure = nil }

    // MARK: Risposte

    /// I campi proposti, confrontati con l'ordine attuale.
    func fieldRows(for entry: AdminWorkOrderAssistantEntry) -> [AdminWorkOrderAssistantFieldRow] {
        let s = entry.answer.suggestion
        var rows: [AdminWorkOrderAssistantFieldRow] = []
        func add(_ label: String, _ value: String?, current: String?) {
            guard let value else { return }
            rows.append(AdminWorkOrderAssistantFieldRow(label: label, value: value, unchanged: value == current))
        }
        add(String(localized: "Title"), s.title, current: order.title)
        add(String(localized: "Priority"), s.priority?.localized, current: order.priority?.localized)
        add(String(localized: "Type"), s.type?.localized, current: order.type?.localized)
        add(String(localized: "Category"), s.category, current: order.category)
        add(String(localized: "Estimated duration"), s.estimatedMinutes.map { AdminWorkOrderFormat.duration(minutes: $0) },
            current: order.estimatedDurationMin.map { AdminWorkOrderFormat.duration(minutes: $0) })
        return rows
    }

    /// I campi proposti cambiano davvero qualcosa sull'ordine.
    func canApplyFields(_ entry: AdminWorkOrderAssistantEntry) -> Bool {
        !fieldsUpdate(for: entry.answer.suggestion).isEmpty
    }

    /// Una risposta solo testo a "Improve description" si può usare come descrizione.
    func canUseTextAsDescription(_ entry: AdminWorkOrderAssistantEntry) -> Bool {
        guard let text = entry.answer.text, entry.answer.suggestion.description == nil else { return false }
        return entry.action == AdminWorkOrderAIAction.improveDescription.rawValue && text != order.description
    }

    /// Passi, sicurezza, attrezzi e ricambi non hanno un campo: si possono aggiungere alle note.
    func canAppendToNotes(_ entry: AdminWorkOrderAssistantEntry) -> Bool {
        notesAddition(for: entry) != nil
    }

    /// Le azioni che producono un elenco: se la risposta è solo testo, il testo è l'elenco.
    private static let listActions: Set<String> = [AdminWorkOrderAIAction.generateSteps.rawValue,
                                                   AdminWorkOrderAIAction.safetyCheck.rawValue,
                                                   AdminWorkOrderAIAction.suggestParts.rawValue]

    private func notesAddition(for entry: AdminWorkOrderAssistantEntry) -> String? {
        if let lists = entry.answer.suggestion.listsText { return lists }
        return Self.listActions.contains(entry.action) ? entry.answer.text : nil
    }

    /// Il testo da copiare: la risposta, i campi proposti e gli elenchi.
    func copyText(for entry: AdminWorkOrderAssistantEntry) -> String {
        let s = entry.answer.suggestion
        let parts: [String?] = [
            entry.answer.text,
            s.description,
            fieldRows(for: entry).isEmpty ? nil : fieldRows(for: entry).map { "\($0.label): \($0.value)" }.joined(separator: "\n"),
            s.listsText,
            s.notes,
            entry.answer.raw,
        ]
        return parts.compactMap { $0 }.joined(separator: "\n\n")
    }

    func apply(_ kind: AdminWorkOrderAssistantApply, from entry: AdminWorkOrderAssistantEntry) async {
        guard applyingEntryId == nil else { return }
        let body: AdminWorkOrderUpdate
        switch kind {
        case .fields:
            body = fieldsUpdate(for: entry.answer.suggestion)
        case .textAsDescription:
            var update = AdminWorkOrderUpdate()
            update.description = .some(entry.answer.text)
            body = update
        case .appendToNotes:
            guard let addition = notesAddition(for: entry) else { return }
            var update = AdminWorkOrderUpdate()
            let current = order.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            update.notes = .some(current.isEmpty ? addition : current + "\n\n" + addition)
            body = update
        }
        guard !body.isEmpty else { return }
        applyingEntryId = entry.id
        applyError = nil
        defer { applyingEntryId = nil }
        do {
            let updated = try await api.update(order.id, body)
            // La PATCH non rimanda la procedura: per il contesto di Aria si tiene quella che c'era.
            var local = updated
            if local.procedure == nil { local.procedure = order.procedure }
            order = local
            if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index].applied.insert(kind) }
            onUpdated(updated)
        } catch {
            applyError = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    /// Solo i campi che cambiano rispetto all'ordine attuale.
    private func fieldsUpdate(for s: AdminWorkOrderAISuggestion) -> AdminWorkOrderUpdate {
        var body = AdminWorkOrderUpdate()
        if let title = s.title, title != order.title { body.title = .some(title) }
        if let description = s.description, description != order.description { body.description = .some(description) }
        if let priority = s.priority, priority != order.priority { body.priority = .some(priority.rawValue) }
        if let type = s.type, type != order.type { body.type = .some(type.rawValue) }
        if let category = s.category, category != order.category { body.category = .some(category) }
        if let minutes = s.estimatedMinutes, minutes != order.estimatedDurationMin { body.estimatedDurationMin = .some(minutes) }
        if let notes = s.notes, notes != order.notes { body.notes = .some(notes) }
        return body
    }
}
