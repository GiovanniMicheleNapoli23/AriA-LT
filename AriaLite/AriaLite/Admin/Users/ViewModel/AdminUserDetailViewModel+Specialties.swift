//
//  AdminUserDetailViewModel+Specialties.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le specialità di un lavoratore sul campo (§5.4): le sette categorie più quelle che ha già, l'elenco salvato
//  viene da GET /v1/members/{id}; "Save specialties" si accende quando l'insieme scelto cambia e manda la lista intera.
//

import Foundation

extension AdminUserDetailViewModel {
    /// Le specialità salvate; senza i dettagli non si sa e la modifica resta spenta.
    var savedSpecialties: [String] { details?.specialties ?? [] }

    var specialtiesReady: Bool { details != nil }

    /// Le categorie, più ogni altro valore che la persona ha già.
    var specialtyChoices: [String] { AdminUsersRules.specialtyChoices(saved: savedSpecialties) }

    var canSaveSpecialties: Bool {
        specialtiesReady && !isWorking && specialtyDraft != Set(savedSpecialties)
    }

    /// "Mechanical, Electrical" per la riga della scheda.
    var specialtiesSummary: String {
        savedSpecialties.map(Self.specialtyTitle).joined(separator: ", ")
    }

    /// Il nome della categoria (`workOrders.category` della web); un valore sconosciuto si mostra com'è.
    static func specialtyTitle(_ value: String) -> String {
        switch value {
        case "mechanical": String(localized: "Mechanical")
        case "electrical": String(localized: "Electrical")
        case "hydraulic": String(localized: "Hydraulic")
        case "pneumatic": String(localized: "Pneumatic")
        case "instrumentation": String(localized: "Instrumentation")
        case "cleaning": String(localized: "Cleaning")
        case "general": String(localized: "General")
        default: value
        }
    }

    /// All'apertura della pagina: si riparte dalle salvate.
    func startSpecialties() {
        specialtyDraft = Set(savedSpecialties)
    }

    func toggleSpecialty(_ value: String) {
        if specialtyDraft.contains(value) { specialtyDraft.remove(value) } else { specialtyDraft.insert(value) }
    }

    func saveSpecialties() {
        guard canSaveSpecialties, let api = owner.api else { return }
        // La lista intera, nell'ordine delle voci.
        let list = specialtyChoices.filter { specialtyDraft.contains($0) }
        Task {
            let ok = await write {
                try await api.setSpecialties(userId: userId, list)
                return String(localized: "Specialties saved.")
            }
            if ok {
                await loadDetails()
                startSpecialties()
                specialtyPageCloses += 1
            }
        }
    }

    // MARK: - Assign a work order (§5.4)

    var canAssign: Bool { controls.assignWorkOrder }

    func startAssigning() {
        guard canAssign, !isWorking else { return }
        assignment = AdminUserAssignWorkOrderViewModel(owner: owner) { [weak self] orderId in
            await self?.assign(orderId) ?? false
        }
    }

    /// PATCH /v1/work-orders/{id}: l'ordine va alla persona, col suo nome.
    private func assign(_ orderId: String) async -> Bool {
        guard let api = owner.api, let name = row?.displayName else { return false }
        let ok = await write {
            try await api.assignWorkOrder(id: orderId, to: userId, name: name)
            return String(localized: "Work order assigned.")
        }
        if ok { await loadDetails() }
        return ok
    }
}
