//
//  AdminWorkOrderTemplateFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form di un modello di ordine: creazione (POST, nello stabilimento attivo) e modifica (PATCH).
//  Titolo, descrizione, tipo, priorità, categoria, zona, asset, durata stimata, passi (aggiungi, riordina,
//  elimina) e ricambi dal magazzino con la quantità.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminWorkOrderTemplateFormViewModel: Identifiable {
    /// Un passo del modello, con un id stabile per riordinarlo e modificarlo.
    struct Step: Identifiable, Hashable {
        let id = UUID()
        var text: String
    }

    let template: AdminWorkOrderTemplate?
    let backend: AriaBackend
    let catalog: AdminWorkOrderPartCatalog
    private let onSaved: (AdminWorkOrderTemplate) -> Void

    var title: String
    var description: String
    var type: AdminWorkOrderType
    var priority: AdminWorkOrderPriority
    var category: String
    var zone: String
    var assetTag: String?
    var estimatedMinutes: String
    var steps: [Step]
    var newStep = ""
    private(set) var parts: [AdminWorkOrderTemplatePart]
    /// Quantità del prossimo ricambio aggiunto.
    var newPartQuantity = "1"

    private(set) var isSaving = false
    private(set) var errorMessage: String?
    @ObservationIgnored private var originalSnapshot: [String] = []

    init(template: AdminWorkOrderTemplate?, backend: AriaBackend, catalog: AdminWorkOrderPartCatalog,
         onSaved: @escaping (AdminWorkOrderTemplate) -> Void) {
        self.template = template
        self.backend = backend
        self.catalog = catalog
        self.onSaved = onSaved
        title = template?.title ?? ""
        description = template?.description ?? ""
        let type = template?.type ?? .preventive
        self.type = type == .unknown ? .preventive : type
        let priority = template?.priority ?? .medium
        self.priority = priority == .unknown ? .medium : priority
        category = template?.category ?? ""
        zone = template?.zone ?? ""
        assetTag = template?.assetTag
        estimatedMinutes = template?.estimatedDurationMin.map(String.init) ?? ""
        steps = (template?.steps ?? []).map { Step(text: $0) }
        parts = (template?.parts ?? []).compactMap(AdminWorkOrderTemplatePart.init(json:))
        originalSnapshot = snapshot
    }

    var isCreating: Bool { template == nil }

    var screenTitle: String {
        isCreating ? String(localized: "New Template") : String(localized: "Edit Template")
    }

    func loadChoices() async {
        async let parts: Void = catalog.loadParts()
        async let assets: Void = catalog.loadAssets()
        _ = await (parts, assets)
    }

    // MARK: Asset

    var assetChoices: [AdminWorkOrderChoice] { catalog.assetChoices }
    var assetsUnavailable: Bool { catalog.assetsUnavailable }

    var assetLabel: String {
        guard let tag = assetTag else { return String(localized: "None") }
        return AdminWorkOrderFormat.joined([tag, catalog.asset(tag)?.name])
    }

    /// Scegliere un asset propone la sua zona, se non è già scritta.
    func selectAsset(_ tag: String?) {
        assetTag = tag
        if Self.trimmed(zone) == nil, let assetZone = catalog.asset(tag)?.zone { zone = assetZone }
    }

    // MARK: Passi

    var canAddStep: Bool { Self.trimmed(newStep) != nil }

    func addStep() {
        guard let text = Self.trimmed(newStep) else { return }
        steps.append(Step(text: text))
        newStep = ""
    }

    /// Lo spostamento di `onMove`: `destination` conta anche le righe spostate.
    func moveSteps(from source: IndexSet, to destination: Int) {
        let moving = source.map { steps[$0] }
        var remaining = steps.indices.filter { !source.contains($0) }.map { steps[$0] }
        let target = destination - source.count { $0 < destination }
        remaining.insert(contentsOf: moving, at: min(max(target, 0), remaining.count))
        steps = remaining
    }

    func deleteSteps(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where steps.indices.contains(index) { steps.remove(at: index) }
    }

    // MARK: Ricambi

    var partChoices: [AdminWorkOrderChoice] { catalog.partChoices }
    var partsUnavailable: Bool { catalog.partsUnavailable }

    /// Un ricambio scelto dal magazzino, con la quantità scritta.
    func addPart(_ id: String?) {
        guard let option = catalog.part(id) else { return }
        let quantity = AdminWorkOrderCostFormat.number(newPartQuantity).flatMap { $0 > 0 ? $0 : nil } ?? 1
        parts.append(AdminWorkOrderTemplatePart(option: option, quantity: quantity))
        newPartQuantity = "1"
    }

    func deleteParts(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where parts.indices.contains(index) { parts.remove(at: index) }
    }

    func partSubtitle(_ part: AdminWorkOrderTemplatePart) -> String {
        AdminWorkOrderFormat.joined([part.code, part.quantity.map { String(localized: "Qty \($0)") }])
    }

    // MARK: Controlli

    private var minutes: Int? { Int(estimatedMinutes.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil } }

    var validationMessage: String? {
        if Self.trimmed(title) == nil { return String(localized: "Add a title.") }
        if isCreating, backend.activePlantId == nil { return String(localized: "Choose a plant first.") }
        if !AdminWorkOrderCostFormat.isBlank(estimatedMinutes), minutes == nil {
            return String(localized: "The estimated duration must be a whole number of minutes.")
        }
        return nil
    }

    /// Tutto quello che il form manda, per sapere se qualcosa è cambiato.
    private var snapshot: [String] {
        [title, description, type.rawValue, priority.rawValue, category, zone, assetTag ?? "", estimatedMinutes]
            + steps.map(\.text) + ["#parts"] + parts.map { "\($0.fields)" }
    }

    var hasChanges: Bool { snapshot != originalSnapshot || Self.trimmed(newStep) != nil }

    var canSave: Bool { validationMessage == nil && !isSaving && (isCreating || hasChanges) }

    // MARK: Salvataggio

    func save() async -> Bool {
        guard canSave else { return false }
        // Un passo scritto ma non ancora aggiunto vale lo stesso.
        addStep()
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let api = AdminWorkOrdersAPI(api: backend.api)
        let stepTexts = steps.compactMap { Self.trimmed($0.text) }
        let partsJSON = parts.map(\.json)
        do {
            let saved: AdminWorkOrderTemplate
            if let template {
                saved = try await api.updateTemplate(template.id, AdminWorkOrderTemplateUpdate(
                    title: Self.trimmed(title) ?? template.title, description: Self.trimmed(description),
                    type: type.rawValue, priority: priority.rawValue, category: Self.trimmed(category),
                    zone: Self.trimmed(zone), assetTag: assetTag, estimatedDurationMin: minutes,
                    steps: stepTexts, parts: partsJSON))
            } else {
                saved = try await api.createTemplate(AdminWorkOrderTemplateCreate(
                    title: Self.trimmed(title) ?? "", description: Self.trimmed(description),
                    type: type.rawValue, priority: priority.rawValue, category: Self.trimmed(category),
                    zone: Self.trimmed(zone), assetTag: assetTag, estimatedDurationMin: minutes,
                    steps: stepTexts, parts: partsJSON, plantId: backend.activePlantId ?? ""))
            }
            onSaved(saved)
            return true
        } catch {
            errorMessage = AdminWorkOrderFailure.message(for: error, backend: backend)
            return false
        }
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
