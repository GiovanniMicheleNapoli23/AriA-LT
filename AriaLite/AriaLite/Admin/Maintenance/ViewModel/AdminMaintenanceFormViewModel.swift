//
//  AdminMaintenanceFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Crea un piano (POST /v1/maintenance-plans) o ne modifica uno (PATCH /v1/maintenance-plans/{plan_id}).
//  La modifica manda solo quello che è cambiato; un campo svuotato si toglie (null).
//  Passi e ricambi si scrivono uno per riga; gli asset correlati separati da virgole.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMaintenanceFormViewModel {
    let backend: AriaBackend
    /// `nil`: piano nuovo.
    let original: AdminMaintenancePlan?

    var name: String
    /// Valori grezzi: una frequenza o uno stato che l'app non conosce resta scelto finché non si cambia.
    var frequency: String
    var status: String
    var plantId: String?
    var assetTag: String
    var relatedAssets: String
    var category: String
    var zone: String
    var description: String
    var tasksText: String
    var sparePartsText: String
    var frequencyHours: String
    var estimatedDuration: String
    var days: Set<String>
    var startsOn: Date?
    var endsOn: Date?
    var lastDoneAt: Date?
    var nextDueAt: Date?

    private(set) var isSaving = false
    var errorMessage: String?
    /// Gli asset da cui scegliere (GET /v1/assets): facoltativi, se non arrivano il tag si scrive a mano.
    private(set) var assets: [AdminWorkOrderAsset] = []

    init(backend: AriaBackend, editing plan: AdminMaintenancePlan?) {
        self.backend = backend
        original = plan
        name = plan?.name ?? ""
        frequency = plan?.frequency ?? AdminMaintenanceFrequency.monthly.rawValue
        // Un piano scritto a mano parte approvato: il default del server (draft) non si vedrebbe nella lista di
        // default. Lo stato resta modificabile nel form.
        status = plan?.status ?? AdminMaintenanceStatus.approved.rawValue
        plantId = plan?.plantId ?? backend.activePlantId ?? backend.plants.first?.id
        assetTag = plan?.assetTag ?? ""
        relatedAssets = (plan?.relatedAssetTags ?? []).joined(separator: ", ")
        category = plan?.category ?? ""
        zone = plan?.zone ?? ""
        description = plan?.description ?? ""
        tasksText = (plan?.tasks ?? []).joined(separator: "\n")
        sparePartsText = (plan?.spareParts ?? []).joined(separator: "\n")
        frequencyHours = plan?.frequencyHours.map { $0.formatted(.number.precision(.fractionLength(0...2)).grouping(.never)) } ?? ""
        estimatedDuration = plan?.estimatedDurationMin.map(String.init) ?? ""
        days = Set(plan?.daysOfWeek ?? [])
        startsOn = plan?.startsOn
        endsOn = plan?.endsOn
        lastDoneAt = plan?.lastDoneAt
        nextDueAt = plan?.nextDueAt
    }

    var isEditing: Bool { original != nil }
    var title: String { isEditing ? String(localized: "Edit plan") : String(localized: "New plan") }
    var plants: [AriaPlant] { backend.plants }
    var showsDays: Bool { frequency == AdminMaintenanceFrequency.weekly.rawValue || !days.isEmpty }

    /// Le scelte dei picker: quelle note più il valore attuale se il server ne ha uno nuovo.
    var frequencyOptions: [String] {
        let known = AdminMaintenanceFrequency.allCases.map(\.rawValue)
        return known.contains(frequency) ? known : known + [frequency]
    }

    var statusOptions: [String] {
        let known = AdminMaintenanceStatus.allCases.map(\.rawValue)
        return known.contains(status) ? known : known + [status]
    }

    func frequencyLabel(_ raw: String) -> String { AdminMaintenanceFrequency.label(for: raw) }
    func statusLabel(_ raw: String) -> String { AdminMaintenanceStatus.label(for: raw) }

    // MARK: Asset

    func loadAssets() async {
        guard assets.isEmpty else { return }
        if let rows = try? await backend.api.call(AdminMaintenanceAPI.assets()) { assets = rows.items }
    }

    /// Gli asset dello stabilimento scelto (e quelli senza stabilimento), per tag.
    var assetChoices: [AdminWorkOrderAsset] {
        assets.filter { $0.plantId == nil || plantId == nil || $0.plantId == plantId }
            .sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
    }

    func chooseAsset(_ asset: AdminWorkOrderAsset?) {
        assetTag = asset?.tag ?? ""
        if let asset, trimmed(zone).isEmpty, let assetZone = asset.zone { zone = assetZone }
    }

    // MARK: Lettura dei campi

    private func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Righe non vuote di un testo, senza numeri o trattini in testa.
    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespaces).replacing(/^(\d+[.)]\s*|[-•*]\s*)/, with: "")
        }
        .filter { !$0.isEmpty }
    }

    private var relatedList: [String] {
        relatedAssets.split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// `nil` = campo vuoto; `.some(nil)` = testo che non è un numero valido.
    private var parsedHours: Double?? {
        let text = trimmed(frequencyHours).replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty else { return .some(nil) }
        guard let value = Double(text), value > 0 else { return nil }
        return .some(value)
    }

    private var parsedDuration: Int?? {
        let text = trimmed(estimatedDuration)
        guard !text.isEmpty else { return .some(nil) }
        guard let value = Int(text), value > 0 else { return nil }
        return .some(value)
    }

    // MARK: Validazione

    /// Il primo problema da correggere, mostrato nella scheda; `nil` se si può salvare.
    var validationMessage: String? {
        if trimmed(name).isEmpty { return String(localized: "Enter the plan name.") }
        if !isEditing, plantId == nil { return String(localized: "Select a plant.") }
        if parsedHours == nil { return String(localized: "The interval must be a positive number of hours.") }
        if parsedDuration == nil { return String(localized: "The duration must be a whole number of minutes.") }
        if let startsOn, let endsOn, endsOn < startsOn { return String(localized: "The end date is before the start date.") }
        return nil
    }

    private var changes: AdminPatchBody {
        var body = AdminPatchBody()
        guard let original else { return body }
        func strings(_ list: [String]) -> AriaJSON { .array(list.map(AriaJSON.string)) }
        func date(_ key: String, _ value: Date?, was old: Date?) {
            guard !AdminMaintenanceFormat.sameSecond(value, old) else { return }
            // Il confronto di AdminPatchBody è già stato fatto qui: si scrive sempre il valore nuovo.
            body.value(key, value.map { .string(AdminMaintenanceFormat.wireString($0)) } ?? .null, was: .bool(false))
        }
        body.text("name", name, was: original.name)
        body.value("frequency", .string(frequency), was: .string(original.frequency))
        if case .some(let hours) = parsedHours { body.number("frequency_hours", hours, was: original.frequencyHours) }
        body.value("status", .string(status), was: original.status.map(AriaJSON.string) ?? .null)
        if let plantId { body.value("plant_id", .string(plantId), was: original.plantId.map(AriaJSON.string) ?? .null) }
        body.text("asset_tag", assetTag, was: original.assetTag)
        body.value("related_asset_tags", strings(relatedList), was: strings(original.relatedAssetTags))
        body.text("category", category, was: original.category)
        body.text("zone", zone, was: original.zone)
        body.text("description", description, was: original.description)
        body.value("tasks", strings(Self.lines(tasksText)), was: strings(original.tasks))
        body.value("spare_parts", strings(Self.lines(sparePartsText)), was: strings(original.spareParts))
        if case .some(let minutes) = parsedDuration {
            body.number("estimated_duration_min", minutes.map(Double.init), was: original.estimatedDurationMin.map(Double.init))
        }
        let orderedDays = AdminMaintenanceWeekday.allCases.map(\.rawValue).filter(days.contains)
        body.value("days_of_week", strings(orderedDays), was: strings(original.daysOfWeek))
        date("starts_on", startsOn, was: original.startsOn)
        date("ends_on", endsOn, was: original.endsOn)
        date("last_done_at", lastDoneAt, was: original.lastDoneAt)
        date("next_due_at", nextDueAt, was: original.nextDueAt)
        return body
    }

    var canSave: Bool {
        guard validationMessage == nil, !isSaving else { return false }
        if let original { return original.serverId != nil && !changes.isEmpty }
        return true
    }

    // MARK: Salvataggio

    /// Il piano salvato, o `nil` se il server ha rifiutato (il motivo è in `errorMessage`).
    func save() async -> AdminMaintenancePlan? {
        guard canSave else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let original {
                guard let id = original.serverId else { return nil }
                return try await backend.api.call(AdminMaintenanceAPI.update(id: id, changes))
            }
            guard let plantId, case .some(let hours) = parsedHours, case .some(let minutes) = parsedDuration else { return nil }
            func optional(_ value: String) -> String? { trimmed(value).isEmpty ? nil : trimmed(value) }
            func wire(_ value: Date?) -> String? { value.map(AdminMaintenanceFormat.wireString) }
            let body = AdminMaintenancePlanCreate(
                name: trimmed(name), frequency: frequency, plantId: plantId, status: status,
                frequencyHours: hours, assetTag: optional(assetTag), relatedAssetTags: relatedList,
                category: optional(category), zone: optional(zone), description: optional(description),
                tasks: Self.lines(tasksText), spareParts: Self.lines(sparePartsText),
                estimatedDurationMin: minutes, startsOn: wire(startsOn), endsOn: wire(endsOn),
                daysOfWeek: AdminMaintenanceWeekday.allCases.map(\.rawValue).filter(days.contains),
                lastDoneAt: wire(lastDoneAt), nextDueAt: wire(nextDueAt))
            return try await backend.api.call(AdminMaintenanceAPI.create(body))
        } catch {
            errorMessage = AdminMaintenanceFailure.message(for: error, backend: backend)
            return nil
        }
    }
}
