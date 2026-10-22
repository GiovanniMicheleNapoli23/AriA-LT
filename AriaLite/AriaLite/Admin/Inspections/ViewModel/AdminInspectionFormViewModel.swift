//
//  AdminInspectionFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Crea un'ispezione (POST /v1/inspections) o ne modifica una (PATCH /v1/inspections/{id}).
//  La modifica manda solo quello che è cambiato; un campo svuotato si toglie (null). Gli item si aggiungono,
//  tolgono e riordinano con pulsanti: la lista, se cambia, parte intera (il server la sostituisce).
//

import Foundation
import Observation

/// Un controllo nel form: il testo si modifica, spunta e nota di un item esistente restano quelli del server.
struct AdminInspectionFormItem: Identifiable, Equatable {
    let id: String
    var description: String
    var isChecked = false
    var notes: String?
}

@MainActor
@Observable
final class AdminInspectionFormViewModel {
    let backend: AriaBackend
    /// `nil`: ispezione nuova.
    let original: AdminInspection?

    var title: String
    var plantId: String?
    var assetTag: String
    var zone: String
    var assignedTo: String
    var notes: String
    var hasDueDate: Bool
    var dueDate: Date
    var items: [AdminInspectionFormItem]

    private(set) var assets: [AdminAsset] = []
    private(set) var isLoadingAssets = false
    private(set) var isSaving = false
    var errorMessage: String?
    /// L'ultimo item aggiunto: la vista gli dà il focus.
    private(set) var lastAddedItemId: String?

    init(backend: AriaBackend, editing inspection: AdminInspection?) {
        self.backend = backend
        original = inspection
        title = inspection?.title ?? ""
        plantId = inspection?.plantId ?? backend.activePlantId ?? backend.plants.first?.id
        assetTag = inspection?.assetTag ?? ""
        zone = inspection?.zone ?? ""
        assignedTo = inspection?.assignedTo ?? ""
        notes = inspection?.notes ?? ""
        hasDueDate = inspection?.dueDate != nil
        dueDate = inspection?.dueDate ?? Self.defaultDueDate
        items = (inspection?.items ?? []).map {
            AdminInspectionFormItem(id: $0.serverId ?? UUID().uuidString, description: $0.description,
                                    isChecked: $0.isChecked, notes: $0.notes)
        }
    }

    /// Domani alle 17: una scadenza di fine giornata lavorativa.
    private static var defaultDueDate: Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    var isEditing: Bool { original != nil }
    var screenTitle: String { isEditing ? String(localized: "Edit inspection") : String(localized: "New inspection") }
    var plants: [AriaPlant] { backend.plants }

    // MARK: Asset

    /// Gli asset dello stabilimento scelto (quelli senza stabilimento valgono per tutti).
    var assetChoices: [AdminAsset] {
        assets.filter { plantId == nil || $0.plantId == nil || $0.plantId == plantId }
            .sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
    }

    func loadAssets() async {
        guard assets.isEmpty, !isLoadingAssets else { return }
        isLoadingAssets = true
        defer { isLoadingAssets = false }
        // Il menu degli asset è un aiuto: se non arriva, il tag si scrive a mano.
        assets = (try? await backend.api.call(AdminAssetsAPI.assets(status: nil)))?.items ?? []
    }

    func choose(_ asset: AdminAsset) {
        assetTag = asset.tag
        if trimmed(zone).isEmpty, let assetZone = asset.zone { zone = assetZone }
    }

    // MARK: Item

    func addItem() {
        let item = AdminInspectionFormItem(id: UUID().uuidString, description: "")
        items.append(item)
        lastAddedItemId = item.id
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
    }

    func canMoveUp(_ id: String) -> Bool { items.firstIndex { $0.id == id }.map { $0 > 0 } ?? false }
    func canMoveDown(_ id: String) -> Bool { items.firstIndex { $0.id == id }.map { $0 < items.count - 1 } ?? false }

    func moveUp(_ id: String) { move(id, by: -1) }
    func moveDown(_ id: String) { move(id, by: 1) }

    private func move(_ id: String, by offset: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }), items.indices.contains(index + offset) else { return }
        items.swapAt(index, index + offset)
    }

    // MARK: Validazione

    private func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func optional(_ value: String) -> String? { trimmed(value).isEmpty ? nil : trimmed(value) }

    var validationMessage: String? {
        if trimmed(title).isEmpty { return String(localized: "Enter a title for the inspection.") }
        if !isEditing, plantId == nil { return String(localized: "Select a plant.") }
        return nil
    }

    /// Gli item da mandare: senza i vuoti, numerati nell'ordine a schermo.
    private var itemBodies: [AdminInspectionItemBody] {
        items.filter { !trimmed($0.description).isEmpty }.enumerated().map { index, item in
            AdminInspectionItemBody(id: item.id, order: index, description: trimmed(item.description),
                                    isChecked: item.isChecked, notes: item.notes)
        }
    }

    private var changes: AdminPatchBody {
        var body = AdminPatchBody()
        guard let original else { return body }
        body.text("title", title, was: original.title)
        body.text("asset_tag", assetTag, was: original.assetTag)
        body.text("zone", zone, was: original.zone)
        body.text("assigned_to", assignedTo, was: original.assignedTo)
        body.text("notes", notes, was: original.notes)
        if let plantId { body.value("plant_id", .string(plantId), was: original.plantId.map(AriaJSON.string) ?? .null) }
        let originalDue = original.dueDate.map { AriaJSON.string(Self.wire($0)) } ?? .null
        body.value("due_date", hasDueDate ? .string(Self.wire(dueDate)) : .null, was: originalDue)
        let oldItems = original.items.map { AdminInspectionItemBody(id: $0.serverId ?? "", order: $0.order, description: $0.description,
                                                                    isChecked: $0.isChecked, notes: $0.notes).json }
        let newItems = itemBodies.map(\.json)
        // Stesso testo e stesso ordine: la lista non si manda (non si toccano spunte e note).
        if oldItems.map(Self.signature) != newItems.map(Self.signature) { body.value("items", .array(newItems), was: .null) }
        return body
    }

    private static func wire(_ date: Date) -> String { date.formatted(.iso8601) }

    /// Id e testo: l'ordine nell'elenco decide il resto.
    private static func signature(_ item: AriaJSON) -> String {
        (item["id"]?.stringValue ?? "") + "|" + (item["description"]?.stringValue ?? "")
    }

    var canSave: Bool {
        guard validationMessage == nil, !isSaving else { return false }
        return !isEditing || !changes.isEmpty
    }

    // MARK: Salvataggio

    /// L'ispezione salvata, o `nil` se il server ha rifiutato (il motivo è in `errorMessage`).
    func save() async -> AdminInspection? {
        guard canSave else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let original {
                guard let id = original.serverId else { return nil }
                return try await backend.api.call(AdminInspectionsAPI.update(id: id, changes))
            }
            guard let plantId else { return nil }
            let body = AdminInspectionCreate(title: trimmed(title), plantId: plantId, assetTag: optional(assetTag),
                                             zone: optional(zone), assignedTo: optional(assignedTo), notes: optional(notes),
                                             dueDate: hasDueDate ? Self.wire(dueDate) : nil, items: itemBodies)
            return try await backend.api.call(AdminInspectionsAPI.create(body))
        } catch {
            errorMessage = AdminInspectionsFailure.message(for: error, backend: backend)
            return nil
        }
    }
}
