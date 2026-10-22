//
//  AdminVendorFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo di un fornitore: nuovo (POST /v1/vendors, nello stabilimento attivo) o modifica (PATCH con i
//  soli campi cambiati; un campo svuotato si manda come null). I campi sono testo come li scrive l'utente:
//  email e sito si controllano qui, al salvataggio.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminVendorFormViewModel: Identifiable {
    enum Mode {
        case create
        case edit(AdminVendor)
    }

    let mode: Mode
    let owner: AdminVendorsViewModel
    /// Il fornitore salvato, per chi ha aperto il modulo (il dettaglio).
    private let onSaved: ((AdminVendor) -> Void)?

    // MARK: - Campi

    var name = ""
    var companyName = ""
    var vendorType = ""
    var email = ""
    var phone = ""
    var website = ""
    var address = ""
    var city = ""
    var country = ""
    var notes = ""
    /// Senza rating il fornitore non è valutato (`null` sul server).
    var hasRating = false
    var rating = 3.0

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(mode: Mode, owner: AdminVendorsViewModel, onSaved: ((AdminVendor) -> Void)? = nil) {
        self.mode = mode
        self.owner = owner
        self.onSaved = onSaved
        if case .edit(let vendor) = mode { fill(from: vendor) }
    }

    private func fill(from vendor: AdminVendor) {
        name = vendor.name
        companyName = vendor.companyName ?? ""
        vendorType = vendor.vendorType ?? ""
        email = vendor.email ?? ""
        phone = vendor.phone ?? ""
        website = vendor.website ?? ""
        address = vendor.address ?? ""
        city = vendor.city ?? ""
        country = vendor.country ?? ""
        notes = vendor.notes ?? ""
        hasRating = vendor.rating != nil
        rating = vendor.clampedRating.map(AdminVendorRating.snapped) ?? 3
    }

    // MARK: - Presentazione

    var isEditing: Bool { if case .edit = mode { true } else { false } }

    var title: String { isEditing ? String(localized: "Edit vendor") : String(localized: "New vendor") }

    var ratingRange: ClosedRange<Double> { AdminVendorRating.range }

    var ratingStep: Double { AdminVendorRating.step }

    var ratingText: String { AdminVendorRating.text(rating) }

    var typeSuggestions: [String] { owner.typeSuggestions }

    var canSave: Bool { !isSaving && !trimmed(name).isEmpty }

    /// Qualcosa è cambiato: chiudere con un trascinamento perderebbe le modifiche.
    var hasChanges: Bool {
        switch mode {
        case .create: !trimmed(name).isEmpty || !trimmed(companyName).isEmpty || !trimmed(notes).isEmpty
        case .edit(let vendor): !patch(from: vendor).isEmpty
        }
    }

    // MARK: - Lettura dei campi

    private struct InvalidField: Error {
        let message: String
    }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func optional(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }

    /// Il rating da mandare: `nil` se spento, altrimenti dentro la scala.
    private var ratingValue: Double? { hasRating ? AdminVendorRating.snapped(rating) : nil }

    /// Controlli leggeri, solo per non mandare al server un testo palesemente sbagliato.
    private func validate() throws {
        guard !trimmed(name).isEmpty else { throw InvalidField(message: String(localized: "Name is required.")) }
        if let email = optional(email), !AdminVendorContact.isPlausibleEmail(email) {
            throw InvalidField(message: String(localized: "Enter a valid email address."))
        }
        if let site = optional(website), AdminVendorContact.websiteURL(site) == nil {
            throw InvalidField(message: String(localized: "Enter a valid website address."))
        }
    }

    // MARK: - Body

    /// Il sito come si salva: con lo schema, anche se l'utente l'ha omesso.
    private func websiteToSend(_ text: String?) -> String? {
        text.map { AdminVendorContact.websiteURL($0)?.absoluteString ?? $0 }
    }

    private func createBody(plantId: String?) -> AdminVendorCreate {
        AdminVendorCreate(
            name: trimmed(name), companyName: optional(companyName), email: optional(email), phone: optional(phone),
            website: websiteToSend(optional(website)), address: optional(address), city: optional(city),
            country: optional(country), vendorType: optional(vendorType), rating: ratingValue,
            notes: optional(notes), plantId: plantId
        )
    }

    /// Solo i campi diversi dal fornitore di partenza.
    private func patch(from vendor: AdminVendor) -> AdminVendorUpdate {
        var update = AdminVendorUpdate()
        func text(_ field: AdminVendorUpdate.Field, _ old: String?, _ new: String?) {
            if old != new { update.fields[field] = new.map(AriaJSON.string) ?? .null }
        }
        if trimmed(name) != vendor.name { update.fields[.name] = .string(trimmed(name)) }
        text(.companyName, vendor.companyName, optional(companyName))
        text(.vendorType, vendor.vendorType, optional(vendorType))
        text(.email, vendor.email, optional(email))
        text(.phone, vendor.phone, optional(phone))
        // Confronto sul testo scritto: "acme.com" lasciato com'era non è una modifica.
        if optional(website) != vendor.website {
            update.fields[.website] = websiteToSend(optional(website)).map(AriaJSON.string) ?? .null
        }
        text(.address, vendor.address, optional(address))
        text(.city, vendor.city, optional(city))
        text(.country, vendor.country, optional(country))
        text(.notes, vendor.notes, optional(notes))
        // Un rating fuori scala dal server si confronta già riportato in scala: senza ritocchi non cambia.
        if ratingValue != vendor.clampedRating.map(AdminVendorRating.snapped) {
            update.fields[.rating] = ratingValue.map(AriaJSON.number) ?? .null
        }
        return update
    }

    // MARK: - Salvataggio

    /// `true` se salvato (o niente da salvare): il modulo si può chiudere.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        do { try validate() } catch {
            errorMessage = (error as? InvalidField)?.message ?? error.localizedDescription
            return false
        }
        let api = AdminVendorsAPI(api: owner.backend.api)
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                let created = try await api.create(createBody(plantId: owner.backend.activePlantId))
                owner.didCreate(created)
                onSaved?(created)
            case .edit(let vendor):
                let update = patch(from: vendor)
                guard !update.isEmpty else { return true }
                let saved = try await api.update(id: vendor.id, update)
                owner.didSave(saved)
                onSaved?(saved)
            }
            return true
        } catch {
            if let failure = AdminVendorsFailure.from(error, action: .write, backend: owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
    }
}
