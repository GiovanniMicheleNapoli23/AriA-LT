//
//  AdminWorkOrderFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form di un ordine: creazione (POST /v1/work-orders) e modifica (PATCH, solo i campi cambiati).
//  Controlla i campi, offre asset, persone e squadre dello stabilimento scelto e salva.
//  La zona si sceglie solo creando: WorkOrderUpdate non la accetta.
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

    private var trimmedTitle: String { draft.title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var minutesText: String { draft.estimatedMinutes.trimmingCharacters(in: .whitespaces) }

    /// I minuti scritti; `nil` se il campo è vuoto (o non valido, vedi `minutesAreValid`).
    private var minutes: Int? { Int(minutesText).flatMap { $0 > 0 ? $0 : nil } }

    /// Vuoto o un numero intero positivo.
    private var minutesAreValid: Bool { minutesText.isEmpty || minutes != nil }

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
        return directory.user(id)?.displayName ?? currentAssigneeName ?? id
    }

    var teamLabel: String {
        guard let id = draft.teamId else { return String(localized: "None") }
        return directory.team(id)?.name ?? id
    }

    /// Il nome libero dell'ordine in modifica: vale finché l'elenco delle persone non arriva.
    private var currentAssigneeName: String? {
        if case .edit(let order) = mode { return order.assignedTo }
        return nil
    }

    var usersUnavailable: Bool { directory.unavailable.contains(.users) }
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
                let body = updateBody()
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

    private func createBody() -> AdminWorkOrderCreate {
        let d = draft
        return AdminWorkOrderCreate(
            title: trimmedTitle,
            plantId: d.plantId ?? "",
            type: d.type.rawValue,
            category: Self.nonEmpty(d.category),
            priority: d.priority.rawValue,
            status: d.status.rawValue,
            assetTag: d.assetTag,
            zone: Self.nonEmpty(d.zone),
            description: Self.nonEmpty(d.description),
            assignedTo: directory.user(d.assignedUserId)?.displayName,
            assignedToTeamId: d.teamId,
            assignedToUserId: d.assignedUserId,
            estimatedDurationMin: minutes,
            notes: Self.nonEmpty(d.notes),
            scheduledDate: d.hasScheduledDate ? AdminWorkOrderWireDate.string(d.scheduledDate) : nil,
            dueDate: d.hasDueDate ? AdminWorkOrderWireDate.string(d.dueDate) : nil
        )
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
            body.assignedTo = .some(directory.user(d.assignedUserId)?.displayName)
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
