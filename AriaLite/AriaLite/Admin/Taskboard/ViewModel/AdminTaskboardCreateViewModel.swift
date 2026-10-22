//
//  AdminTaskboardCreateViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio di creazione rapida: un task con titolo e colonna (POST /v1/work-orders), una bozza dell'AI
//  (POST /v1/work-orders/ai-draft) che riempie descrizione, priorità e durata prima di salvare, oppure un
//  ordine da modello (POST …/{id}/apply, poi POST /v1/work-orders con i campi proposti).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminTaskboardCreateViewModel: Identifiable {
    let id = UUID()
    private let backend: AriaBackend
    private let onCreated: (AdminWorkOrder) -> Void

    var title = ""
    var details = ""
    var priority: AdminWorkOrderPriority = .medium
    var status: AdminWorkOrderStatus

    private(set) var templates: [AdminWorkOrderTemplate] = []
    private(set) var isLoadingTemplates = false
    private(set) var templatesMessage: String?
    /// Il modello che si sta applicando.
    private(set) var applyingTemplateId: String?

    private(set) var isSaving = false
    private(set) var isDrafting = false
    private(set) var errorMessage: String?
    /// Cosa ha compilato l'AI, o cosa ha risposto se non c'era niente da compilare.
    private(set) var aiNote: String?
    private(set) var didFinish = false

    /// Quello che l'AI propone oltre a descrizione e priorità: si manda col task.
    @ObservationIgnored private var category: String?
    @ObservationIgnored private var estimatedMinutes: Int?
    @ObservationIgnored private var notes: String?

    init(backend: AriaBackend, status: AdminWorkOrderStatus, onCreated: @escaping (AdminWorkOrder) -> Void) {
        self.backend = backend
        self.status = status
        self.onCreated = onCreated
    }

    private var api: AdminWorkOrdersAPI { AdminWorkOrdersAPI(api: backend.api) }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBusy: Bool { isSaving || isDrafting || applyingTemplateId != nil }
    var canCreate: Bool { !trimmedTitle.isEmpty && !isBusy }
    var canDraft: Bool { !trimmedTitle.isEmpty && !isBusy }

    /// Le colonne in cui nasce un task: quelle di lavoro, non quelle di chiusura.
    static let startColumns: [AdminWorkOrderStatus] = [.proposed, .planned, .assigned, .inProgress]

    // MARK: Task

    func create() async {
        guard canCreate else { return }
        guard let plantId = backend.activePlantId else {
            errorMessage = String(localized: "Choose a plant first.")
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let body = AdminWorkOrderCreate(
            title: trimmedTitle, plantId: plantId, type: AdminWorkOrderType.reactive.rawValue, category: category,
            priority: priority.rawValue, status: status.rawValue, description: Self.nonEmpty(details),
            estimatedDurationMin: estimatedMinutes, notes: notes)
        do {
            finish(try await api.create(body))
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    private func finish(_ order: AdminWorkOrder) {
        onCreated(order)
        didFinish = true
    }

    // MARK: Bozza con l'AI

    func draftWithAI() async {
        guard canDraft else { return }
        isDrafting = true
        errorMessage = nil
        aiNote = nil
        defer { isDrafting = false }
        let action = AdminWorkOrderAIAction.completeDraft
        let request = AdminWorkOrderAIDraftRequest(
            action: action.rawValue, title: trimmedTitle, description: Self.nonEmpty(details),
            type: AdminWorkOrderType.reactive.rawValue, category: category, priority: priority.rawValue)
        do {
            let answer = AdminWorkOrderAIAnswer(json: try await api.aiDraft(request))
            fill(from: answer)
        } catch {
            errorMessage = AdminWorkOrderAIFailure.failure(for: error, action: action.rawValue, backend: backend)?.message
        }
    }

    private func fill(from answer: AdminWorkOrderAIAnswer) {
        let s = answer.suggestion
        var text = answer.text
        var filled: [String] = []
        // Una risposta solo testo è la descrizione.
        var description = s.description
        if description == nil, let answerText = text { description = answerText; text = nil }
        if let description, description != details { details = description; filled.append(String(localized: "description")) }
        if let proposed = s.priority, proposed != .unknown, proposed != priority {
            priority = proposed
            filled.append(String(localized: "priority"))
        }
        if let category = s.category { self.category = category; filled.append(String(localized: "category")) }
        if let minutes = s.estimatedMinutes { estimatedMinutes = minutes; filled.append(String(localized: "duration")) }
        let extra = [s.notes, s.listsText].compactMap { $0 }.joined(separator: "\n\n")
        if !extra.isEmpty { notes = extra; filled.append(String(localized: "notes")) }
        aiNote = filled.isEmpty
            ? (text ?? answer.raw ?? String(localized: "The AI had nothing to add."))
            : String(localized: "Filled by AI: \(filled.joined(separator: ", ")). Review before creating.")
    }

    // MARK: Modelli

    func loadTemplates() async {
        guard templates.isEmpty, !isLoadingTemplates else { return }
        isLoadingTemplates = true
        templatesMessage = nil
        defer { isLoadingTemplates = false }
        do {
            let plantId = backend.activePlantId
            templates = try await api.templateList().filter { $0.plantId == nil || plantId == nil || $0.plantId == plantId }
        } catch {
            templatesMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    /// Crea l'ordine dai campi del modello, nella colonna scelta e nello stabilimento attivo.
    func create(from template: AdminWorkOrderTemplate) async {
        guard !isBusy else { return }
        applyingTemplateId = template.id
        errorMessage = nil
        defer { applyingTemplateId = nil }
        do {
            var fields = try await api.applyTemplate(template.id)
            fields["status"] = .string(status.rawValue)
            if fields["plant_id"] == nil || fields["plant_id"] == .null, let plantId = backend.activePlantId {
                fields["plant_id"] = .string(plantId)
            }
            finish(try await api.createOrder(from: fields))
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
        }
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
