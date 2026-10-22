//
//  AdminWorkOrderFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form di un ordine: creazione (POST /v1/work-orders) e modifica (PATCH, solo i campi cambiati).
//  Controlla i campi, offre asset, persone, operatori sul campo e squadre dello stabilimento scelto e salva.
//  Creando, "Draft with Aria" (POST /v1/work-orders/ai-draft) riempie i campi e la procedura: l'utente li
//  rivede prima di salvare e può annullare. I passi scritti a mano o proposti vanno in `checklist_data`. Zona e codice allarme si scelgono solo creando: WorkOrderUpdate non li accetta.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderFormViewModel: Identifiable {
    enum Mode {
        case create
        case edit(AdminWorkOrder)
    }

    let mode: Mode
    let backend: AriaBackend
    let directory: AdminWorkOrderDirectory
    var draft: AdminWorkOrderDraft
    private let original: AdminWorkOrderDraft
    private let onSaved: (AdminWorkOrder) -> Void

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    /// Creando, la pagina aperta (vedi AdminWorkOrderFormViewModel+Steps).
    var step: AdminWorkOrderFormStep = .details

    // Bozza con l'AI
    /// L'azione di ai-draft in corso.
    private(set) var draftingAction: AdminWorkOrderAIAction?
    /// Il form com'era prima dell'ultimo riempimento dell'AI: "Undo" lo rimette.
    private(set) var draftBeforeAI: AdminWorkOrderDraft?
    /// Cosa ha riempito l'AI, da rivedere.
    private(set) var aiFilledFields: [String] = []
    /// Il testo della risposta che non è finito in un campo (spiegazioni, stime motivate…).
    private(set) var aiNote: String?
    private(set) var aiFailure: AdminWorkOrderAssistantFailure?

    init(mode: Mode, backend: AriaBackend, directory: AdminWorkOrderDirectory,
         onSaved: @escaping (AdminWorkOrder) -> Void) {
        self.mode = mode
        self.backend = backend
        self.directory = directory
        self.onSaved = onSaved
        let start: AdminWorkOrderDraft = switch mode {
        case .create: AdminWorkOrderDraft(plantId: backend.activePlantId ?? backend.plants.first?.id)
        case .edit(let order): AdminWorkOrderDraft(order: order)
        }
        draft = start
        original = start
    }

    var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    var title: String {
        isCreating ? String(localized: "New Work Order") : String(localized: "Edit Work Order")
    }

    var hasChanges: Bool { draft != original }

    // MARK: Controlli

    var trimmedTitle: String { draft.title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var minutesText: String { draft.estimatedMinutes.trimmingCharacters(in: .whitespaces) }

    /// I minuti scritti; `nil` se il campo è vuoto (o non valido, vedi `minutesAreValid`).
    var minutes: Int? { Int(minutesText).flatMap { $0 > 0 ? $0 : nil } }

    /// Vuoto o un numero intero positivo.
    var minutesAreValid: Bool { minutesText.isEmpty || minutes != nil }

    /// Il primo problema che impedisce di salvare.
    var validationMessage: String? {
        if trimmedTitle.isEmpty { return String(localized: "Add a title.") }
        if isCreating, draft.plantId == nil { return String(localized: "Choose a plant.") }
        if !minutesAreValid { return String(localized: "The estimated duration must be a whole number of minutes.") }
        return nil
    }

    var canSave: Bool {
        validationMessage == nil && !isSaving && (isCreating || hasChanges)
    }

    // MARK: Scelte

    var plants: [AriaPlant] { backend.plants }

    var plantLabel: String {
        directory.plantName(draft.plantId) ?? draft.plantId ?? String(localized: "None")
    }

    var assetChoices: [AdminWorkOrderChoice] {
        directory.assets(in: draft.plantId).map {
            AdminWorkOrderChoice(id: $0.tag, title: $0.tag, subtitle: AdminWorkOrderFormat.joined([$0.name, $0.zone]))
        }
    }

    var userChoices: [AdminWorkOrderChoice] {
        directory.activeUsers.map {
            AdminWorkOrderChoice(id: $0.id, title: $0.displayName, subtitle: $0.fullName == nil ? nil : $0.email)
        }
    }

    /// Persone dell'azienda, senza chi compare già fra gli operatori.
    var assigneeUsers: [AdminWorkOrderFormAssignee] {
        directory.activeUsers.filter { directory.fieldOperator($0.id) == nil }.map {
            AdminWorkOrderFormAssignee(id: $0.id, title: $0.displayName, subtitle: $0.fullName == nil ? $0.role : $0.email,
                                       availability: nil, workload: nil)
        }
    }

    /// Operatori sul campo: prima i disponibili e i meno carichi.
    var assigneeOperators: [AdminWorkOrderFormAssignee] {
        directory.sortedOperators.map { op in
            AdminWorkOrderFormAssignee(
                id: op.id, title: op.name,
                subtitle: op.specialties.isEmpty ? nil : op.specialties.joined(separator: ", "),
                availability: op.availability,
                workload: Self.workload(count: op.openCount, minutes: op.openMinutes))
        }
    }

    /// "3 open · 2 h 30 min"; niente se non ha lavori aperti.
    private static func workload(count: Int, minutes: Int) -> String {
        guard count > 0 else { return String(localized: "No open work") }
        let open = String(localized: "\(count) open")
        return minutes > 0 ? AdminWorkOrderFormat.joined([open, AdminWorkOrderFormat.duration(minutes: minutes)]) : open
    }

    var teamChoices: [AdminWorkOrderChoice] {
        directory.teams(in: draft.plantId).map {
            AdminWorkOrderChoice(id: $0.id, title: $0.name,
                                 subtitle: $0.memberCount > 0 ? String(localized: "\($0.memberCount) members") : nil)
        }
    }

    var assetLabel: String {
        guard let tag = draft.assetTag else { return String(localized: "None") }
        return AdminWorkOrderFormat.joined([tag, directory.asset(tag)?.name])
    }

    var userLabel: String {
        guard let id = draft.assignedUserId else { return String(localized: "None") }
        return directory.personName(id) ?? currentAssigneeName ?? id
    }

    /// Disponibilità dell'operatore scelto, per il pallino accanto al nome.
    var assigneeAvailability: AriaAvailability? { directory.fieldOperator(draft.assignedUserId)?.availability }

    var teamLabel: String {
        guard let id = draft.teamId else { return String(localized: "None") }
        return directory.team(id)?.name ?? id
    }

    /// Il nome libero dell'ordine in modifica: vale finché l'elenco delle persone non arriva.
    private var currentAssigneeName: String? {
        if case .edit(let order) = mode { return order.assignedTo }
        return nil
    }

    /// Né persone né operatori leggibili: l'assegnatario resta in sola lettura.
    var usersUnavailable: Bool { directory.unavailable.contains(.users) && directory.unavailable.contains(.operators) }
    var teamsUnavailable: Bool { directory.unavailable.contains(.teams) }
    var assetsUnavailable: Bool { directory.unavailable.contains(.assets) }

    func loadChoices() async {
        await directory.loadIfNeeded()
    }

    func selectAsset(_ tag: String?) {
        draft.assetTag = tag
        // Creando, la zona segue l'asset se non è già stata scritta.
        if isCreating, draft.zone.trimmingCharacters(in: .whitespaces).isEmpty, let zone = directory.asset(tag)?.zone {
            draft.zone = zone
        }
    }

    func selectUser(_ id: String?) { draft.assignedUserId = id }

    // MARK: Durata

    /// La durata scritta in ore e minuti ("1 h 30 min"), quando è di almeno un'ora.
    var durationHint: String? { minutes.flatMap { $0 >= 60 ? AdminWorkOrderFormat.duration(minutes: $0) : nil } }

    // MARK: Bozza con l'AI

    /// Nella prima pagina: riempie i campi che mancano. Nella pagina dei passi: scrive la procedura.
    func isDrafting(_ action: AdminWorkOrderAIAction) -> Bool { draftingAction == action }

    var canDraftWithAI: Bool { !trimmedTitle.isEmpty && draftingAction == nil && !isSaving }

    var isDrafting: Bool { draftingAction != nil }

    /// Senza titolo l'AI non parte: il form lo dice accanto al pulsante.
    var needsTitleForAI: Bool { trimmedTitle.isEmpty }

    var aiNotice: String? {
        guard !aiFilledFields.isEmpty else { return nil }
        return String(localized: "Filled by AI: \(aiFilledFields.joined(separator: ", ")). Review before saving.")
    }

    func draftWithAI(_ action: AdminWorkOrderAIAction) async {
        guard canDraftWithAI else { return }
        draftingAction = action
        aiFailure = nil
        defer { draftingAction = nil }
        let d = draft
        let request = AdminWorkOrderAIDraftRequest(
            action: action.rawValue, title: trimmedTitle, description: Self.nonEmpty(d.description),
            type: d.type.rawValue, category: Self.nonEmpty(d.category), priority: d.priority.rawValue,
            assetTag: d.assetTag, alarmCode: Self.nonEmpty(d.alarmCode), zone: Self.nonEmpty(d.zone),
            notes: Self.nonEmpty(d.notes))
        do {
            let json = try await AdminWorkOrdersAPI(api: backend.api).aiDraft(request)
            fill(from: AdminWorkOrderAIAnswer(json: json), action: action)
        } catch {
            aiFailure = AdminWorkOrderAIFailure.failure(for: error, action: action.rawValue, backend: backend)
        }
    }

    /// Riempie il form con la risposta. I passi proposti prendono il posto di quelli scritti (Undo li rimette);
    /// sicurezza, attrezzi e ricambi vanno nella stessa checklist.
    private func fill(from answer: AdminWorkOrderAIAnswer, action: AdminWorkOrderAIAction) {
        let before = draft
        var d = draft
        var filled: [String] = []
        let s = answer.suggestion
        var text = answer.text

        if let title = s.title, title != d.title { d.title = title; filled.append(String(localized: "title")) }
        var description = s.description
        // Una risposta solo testo a "Complete draft" o "Improve description" è la descrizione.
        if description == nil, let answerText = text, [.completeDraft, .improveDescription].contains(action) {
            description = answerText
            text = nil
        }
        // Anche i passi chiesti a "Generate steps" possono arrivare come testo semplice, una riga per passo.
        var steps = s.steps
        if steps.isEmpty, action == .generateSteps, let answerText = text {
            steps = Self.stepLines(answerText)
            if !steps.isEmpty { text = nil }
        }
        if !steps.isEmpty, steps != d.steps.map(\.text) {
            d.steps = steps.map { AdminWorkOrderDraftStep(text: $0) }
            filled.append(String(localized: "steps"))
        }
        if !s.safetyWarnings.isEmpty || !s.toolsNeeded.isEmpty || !s.partsNeeded.isEmpty {
            d.safetyWarnings = s.safetyWarnings
            d.toolsNeeded = s.toolsNeeded
            d.partsNeeded = s.partsNeeded
            filled.append(String(localized: "safety, tools and parts"))
        }
        if let description, description != d.description {
            d.description = description
            filled.append(String(localized: "description"))
        }
        if let category = s.category, category != d.category { d.category = category; filled.append(String(localized: "category")) }
        if let priority = s.priority, priority != d.priority { d.priority = priority; filled.append(String(localized: "priority")) }
        if let type = s.type, type != d.type { d.type = type; filled.append(String(localized: "type")) }
        if let minutes = s.estimatedMinutes, String(minutes) != d.estimatedMinutes {
            d.estimatedMinutes = String(minutes)
            filled.append(String(localized: "duration"))
        }
        if let notes = s.notes, notes != d.notes {
            let current = d.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            d.notes = current.isEmpty ? notes : current + "\n\n" + notes
            filled.append(String(localized: "notes"))
        }

        aiNote = text ?? answer.raw
        if filled.isEmpty {
            if aiNote == nil { aiNote = String(localized: "The AI had nothing to add.") }
            return
        }
        draftBeforeAI = before
        draft = d
        aiFilledFields = filled
    }

    /// Le righe di un elenco in testo ("1. …", "- …"), senza numeri né trattini.
    private static func stepLines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let stripped = trimmed.replacingOccurrences(of: #"^(\d+[.)]|[-•*])\s+"#, with: "", options: .regularExpression)
            // Un titolo come "Steps:" non è un passo.
            if stripped == trimmed, trimmed.hasSuffix(":") { return nil }
            return stripped.isEmpty ? nil : stripped
        }
    }

    func undoAIDraft() {
        guard let before = draftBeforeAI else { return }
        draft = before
        draftBeforeAI = nil
        aiFilledFields = []
        aiNote = nil
    }

    func dismissAINote() {
        aiNote = nil
        aiFailure = nil
    }
    func selectTeam(_ id: String?) { draft.teamId = id }

    // MARK: Salvataggio

    /// `true` se salvato: il form si chiude.
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let api = AdminWorkOrdersAPI(api: backend.api)
        do {
            let saved: AdminWorkOrder
            switch mode {
            case .create:
                saved = try await api.create(createBody())
            case .edit(let order):
                let body = patchBody()
                guard !body.isEmpty else { return true }
                saved = try await api.update(order.id, body)
            }
            onSaved(saved)
            return true
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
            return false
        }
    }

    private func createBody() -> AdminWorkOrderFormCreate {
        let d = draft
        let base = AdminWorkOrderCreate(
            title: trimmedTitle,
            plantId: d.plantId ?? "",
            type: d.type.rawValue,
            category: Self.nonEmpty(d.category),
            priority: d.priority.rawValue,
            status: d.status.rawValue,
            assetTag: d.assetTag,
            zone: Self.nonEmpty(d.zone),
            description: Self.nonEmpty(d.description),
            assignedTo: directory.personName(d.assignedUserId),
            assignedToTeamId: d.teamId,
            assignedToUserId: d.assignedUserId,
            estimatedDurationMin: minutes,
            notes: Self.nonEmpty(d.notes),
            scheduledDate: d.hasScheduledDate ? AdminWorkOrderWireDate.string(d.scheduledDate) : nil,
            dueDate: d.hasDueDate ? AdminWorkOrderWireDate.string(d.dueDate) : nil
        )
        let checklist = AdminWorkOrderChecklist(steps: d.steps, safetyWarnings: d.safetyWarnings,
                                                toolsNeeded: d.toolsNeeded, partsNeeded: d.partsNeeded)
        return AdminWorkOrderFormCreate(base: base, requestedBy: Self.nonEmpty(d.requestedBy),
                                        alarmCode: Self.nonEmpty(d.alarmCode), checklistData: checklist?.jsonText)
    }

    /// Il body comune più `requested_by`, se è cambiato.
    private func patchBody() -> AdminWorkOrderFormPatch {
        var body = AdminWorkOrderFormPatch(base: updateBody())
        if Self.nonEmpty(draft.requestedBy) != Self.nonEmpty(original.requestedBy) {
            body.requestedBy = .some(Self.nonEmpty(draft.requestedBy))
        }
        return body
    }

    /// Solo quello che è cambiato rispetto all'apertura del form; un campo svuotato diventa `null`.
    private func updateBody() -> AdminWorkOrderUpdate {
        let d = draft, o = original
        var body = AdminWorkOrderUpdate()
        if trimmedTitle != o.title { body.title = .some(trimmedTitle) }
        if d.type != o.type { body.type = .some(d.type.rawValue) }
        if d.priority != o.priority { body.priority = .some(d.priority.rawValue) }
        if d.status != o.status { body.status = .some(d.status.rawValue) }
        if d.plantId != o.plantId { body.plantId = .some(d.plantId) }
        if d.assetTag != o.assetTag { body.assetTag = .some(d.assetTag) }
        if Self.nonEmpty(d.category) != Self.nonEmpty(o.category) { body.category = .some(Self.nonEmpty(d.category)) }
        if Self.nonEmpty(d.description) != Self.nonEmpty(o.description) { body.description = .some(Self.nonEmpty(d.description)) }
        if Self.nonEmpty(d.notes) != Self.nonEmpty(o.notes) { body.notes = .some(Self.nonEmpty(d.notes)) }
        if Self.nonEmpty(d.resolutionNotes) != Self.nonEmpty(o.resolutionNotes) {
            body.resolutionNotes = .some(Self.nonEmpty(d.resolutionNotes))
        }
        if d.assignedUserId != o.assignedUserId {
            body.assignedToUserId = .some(d.assignedUserId)
            // Il nome libero segue la persona, così la web non mostra quello vecchio.
            body.assignedTo = .some(directory.personName(d.assignedUserId))
        }
        if d.teamId != o.teamId { body.assignedToTeamId = .some(d.teamId) }
        if d.estimatedMinutes != o.estimatedMinutes { body.estimatedDurationMin = .some(minutes) }
        if d.hasScheduledDate != o.hasScheduledDate || (d.hasScheduledDate && d.scheduledDate != o.scheduledDate) {
            body.scheduledDate = .some(d.hasScheduledDate ? AdminWorkOrderWireDate.string(d.scheduledDate) : nil)
        }
        if d.hasDueDate != o.hasDueDate || (d.hasDueDate && d.dueDate != o.dueDate) {
            body.dueDate = .some(d.hasDueDate ? AdminWorkOrderWireDate.string(d.dueDate) : nil)
        }
        return body
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension AdminWorkOrderChoice {
    /// Le voci che contengono il testo cercato, nel titolo o nel sottotitolo.
    static func matching(_ query: String, in choices: [AdminWorkOrderChoice]) -> [AdminWorkOrderChoice] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return choices }
        return choices.filter {
            $0.title.localizedStandardContains(query) || $0.subtitle?.localizedStandardContains(query) == true
        }
    }
}
