//
//  AdminVendorDetailViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il dettaglio di un fornitore (pagina /vendors/{id} della web): scheda aggiornata dal server, contatti
//  da toccare (mail, telefono, sito), note, date; modifica ed eliminazione (con conferma).
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminVendorDetailViewModel {
    let owner: AdminVendorsViewModel
    private var backend: AriaBackend { owner.backend }

    // MARK: - State

    private(set) var vendor: AdminVendor
    private(set) var isLoading = false
    private(set) var failure: AdminVendorsFailure?
    private(set) var isDeleting = false
    /// Il modulo di modifica aperto (sheet).
    var editForm: AdminVendorFormViewModel?
    /// "Eliminare questo fornitore?" (conferma).
    var showsDeleteConfirmation = false
    /// Errore dell'eliminazione (alert).
    var deleteError: String?
    var isShowingDeleteError: Bool {
        get { deleteError != nil }
        set { if !newValue { deleteError = nil } }
    }

    init(vendor: AdminVendor, owner: AdminVendorsViewModel) {
        self.vendor = vendor
        self.owner = owner
    }

    // MARK: - Caricamento

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await AdminVendorsAPI(api: backend.api).vendor(id: vendor.id)
            vendor = fresh
            owner.didSave(fresh)
            failure = nil
        } catch {
            if let failure = AdminVendorsFailure.from(error, action: .read, backend: backend) { self.failure = failure }
        }
    }

    // MARK: - Scheda

    /// Il rating in scala 0…5, se c'è.
    var ratingValue: Double? { vendor.clampedRating }

    /// I contatti che ci sono, nell'ordine della web. Le righe vuote non si mostrano.
    var contactItems: [AdminVendorContactItem] {
        var items: [AdminVendorContactItem] = []
        if let email = vendor.email {
            items.append(.init(id: "email", label: String(localized: "Email"), value: email,
                               systemImage: "envelope", url: AdminVendorContact.mailURL(email)))
        }
        if let phone = vendor.phone {
            items.append(.init(id: "phone", label: String(localized: "Phone"), value: phone,
                               systemImage: "phone", url: AdminVendorContact.phoneURL(phone)))
        }
        if let website = vendor.website {
            items.append(.init(id: "website", label: String(localized: "Website"), value: website,
                               systemImage: "globe", url: AdminVendorContact.websiteURL(website)))
        }
        let place = [vendor.address, vendor.cityAndCountry].compactMap { $0 }.joined(separator: "\n")
        if !place.isEmpty {
            items.append(.init(id: "address", label: String(localized: "Address"), value: place, systemImage: "mappin.and.ellipse"))
        }
        return items
    }

    /// Creato e aggiornato, come righe etichetta-valore.
    var dateRows: [(label: String, value: String)] {
        [(String(localized: "Created"), vendor.createdAt), (String(localized: "Updated"), vendor.updatedAt)]
            .compactMap { label, date in
                date.map { (label, $0.formatted(date: .abbreviated, time: .shortened)) }
            }
    }

    var showsNotesCard: Bool { vendor.notes != nil || !dateRows.isEmpty }

    // MARK: - Azioni

    func startEditing() {
        editForm = AdminVendorFormViewModel(mode: .edit(vendor), owner: owner) { [weak self] saved in
            self?.vendor = saved
        }
    }

    /// `true` se eliminato: la schermata si chiude. Un 404 vuol dire che non c'era già più.
    func delete() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await AdminVendorsAPI(api: backend.api).delete(id: vendor.id)
        } catch {
            guard let failure = AdminVendorsFailure.from(error, action: .write, backend: backend) else { return false }
            guard failure.isNotFound else {
                deleteError = failure.message
                return false
            }
        }
        owner.didDelete(id: vendor.id)
        return true
    }
}
