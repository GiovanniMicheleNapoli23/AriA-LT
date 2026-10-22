//
//  AdminAssetFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Crea un asset (POST /v1/assets) o ne modifica uno (PATCH /v1/assets/{asset_id}).
//  La modifica manda solo quello che è cambiato; un campo svuotato si toglie (null).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminAssetFormViewModel {
    let backend: AriaBackend
    /// `nil`: asset nuovo.
    let original: AdminAsset?

    var tag: String
    var name: String
    /// Valori grezzi: un tipo o uno stato che l'app non conosce resta scelto finché non si cambia.
    var assetType: String
    var status: String
    var plantId: String?
    var zone: String
    var power: String
    var manufacturer: String
    var model: String
    var serialNumber: String
    var driveTag: String
    var driveType: String
    var description: String
    var notes: String

    private(set) var isSaving = false
    var errorMessage: String?

    init(backend: AriaBackend, editing asset: AdminAsset?) {
        self.backend = backend
        original = asset
        tag = asset?.tag ?? ""
        name = asset?.name ?? ""
        assetType = asset?.assetType ?? AdminAssetType.motor.rawValue
        // Un asset scritto a mano parte approvato: il default del server (draft) non si vedrebbe nella lista di
        // default. Lo stato resta modificabile nel form.
        status = asset?.status ?? AdminAssetStatus.approved.rawValue
        plantId = asset?.plantId ?? backend.activePlantId ?? backend.plants.first?.id
        zone = asset?.zone ?? ""
        power = asset?.powerKw.map { $0.formatted(.number.precision(.fractionLength(0...3)).grouping(.never)) } ?? ""
        manufacturer = asset?.manufacturer ?? ""
        model = asset?.model ?? ""
        serialNumber = asset?.serialNumber ?? ""
        driveTag = asset?.driveTag ?? ""
        driveType = asset?.driveType ?? ""
        description = asset?.description ?? ""
        notes = asset?.notes ?? ""
    }

    var isEditing: Bool { original != nil }
    var title: String { isEditing ? String(localized: "Edit asset") : String(localized: "New asset") }
    var plants: [AriaPlant] { backend.plants }

    /// Le scelte del picker: quelle note più il valore attuale se il server ne ha uno nuovo.
    var typeOptions: [String] {
        let known = AdminAssetType.allCases.map(\.rawValue)
        return known.contains(assetType) ? known : known + [assetType]
    }

    var statusOptions: [String] {
        let known = AdminAssetStatus.allCases.map(\.rawValue)
        return known.contains(status) ? known : known + [status]
    }

    func typeLabel(_ raw: String) -> String { AdminAssetType.label(for: raw) }
    func statusLabel(_ raw: String) -> String { AdminAssetStatus.label(for: raw) }
    func plantLabel(_ id: String) -> String { plants.first { $0.id == id }?.name ?? id }

    // MARK: Validazione

    private func trimmed(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// `nil` = campo vuoto; `.some(nil)` = testo che non è un numero.
    private var parsedPower: Double?? {
        let text = trimmed(power).replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty else { return .some(nil) }
        guard let value = Double(text), value >= 0 else { return nil }
        return .some(value)
    }

    /// Il primo problema da correggere, mostrato sotto il form; `nil` se si può salvare.
    var validationMessage: String? {
        if trimmed(tag).isEmpty { return String(localized: "Enter the asset tag.") }
        if trimmed(name).isEmpty { return String(localized: "Enter the asset name.") }
        if parsedPower == nil { return String(localized: "Power must be a positive number in kW.") }
        if !isEditing, plantId == nil { return String(localized: "Select a plant.") }
        return nil
    }

    private var changes: AdminPatchBody {
        var body = AdminPatchBody()
        guard let original else { return body }
        body.text("tag", tag, was: original.tag)
        body.text("name", name, was: original.name)
        body.value("asset_type", .string(assetType), was: original.assetType.map(AriaJSON.string) ?? .null)
        body.value("status", .string(status), was: original.status.map(AriaJSON.string) ?? .null)
        if let plantId { body.value("plant_id", .string(plantId), was: original.plantId.map(AriaJSON.string) ?? .null) }
        body.text("zone", zone, was: original.zone)
        if case .some(let value) = parsedPower { body.number("power_kw", value, was: original.powerKw) }
        body.text("manufacturer", manufacturer, was: original.manufacturer)
        body.text("model", model, was: original.model)
        body.text("serial_number", serialNumber, was: original.serialNumber)
        body.text("drive_tag", driveTag, was: original.driveTag)
        body.text("drive_type", driveType, was: original.driveType)
        body.text("description", description, was: original.description)
        body.text("notes", notes, was: original.notes)
        return body
    }

    var canSave: Bool {
        guard validationMessage == nil, !isSaving else { return false }
        return !isEditing || !changes.isEmpty
    }

    // MARK: Salvataggio

    /// L'asset salvato, o `nil` se il server ha rifiutato (il motivo è in `errorMessage`).
    func save() async -> AdminAsset? {
        guard canSave else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            if let original {
                guard let id = original.serverId else { return nil }
                return try await backend.api.call(AdminAssetsAPI.update(assetId: id, changes))
            }
            guard let plantId, case .some(let powerKw) = parsedPower else { return nil }
            func optional(_ value: String) -> String? { trimmed(value).isEmpty ? nil : trimmed(value) }
            let body = AdminAssetCreate(tag: trimmed(tag), name: trimmed(name), assetType: assetType, status: status,
                                        plantId: plantId, zone: optional(zone), powerKw: powerKw,
                                        description: optional(description), manufacturer: optional(manufacturer),
                                        model: optional(model), serialNumber: optional(serialNumber),
                                        driveTag: optional(driveTag), driveType: optional(driveType), notes: optional(notes))
            return try await backend.api.call(AdminAssetsAPI.create(body))
        } catch {
            errorMessage = AdminAssetsFailure.message(for: error, backend: backend)
            return nil
        }
    }
}
