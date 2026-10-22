//
//  AdminMobileUserSpecialtiesViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il foglio che cambia le specialità di un operatore (PATCH con la lista intera): si aggiungono e si tolgono
//  etichette libere, il server tiene al massimo 100 voci. Il salvataggio lo fa la lista, che aggiorna la riga.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMobileUserSpecialtiesViewModel: Identifiable {
    static let maxCount = 100

    let list: AdminMobileUsersViewModel
    let user: AdminMobileUser
    private(set) var specialties: [String]
    /// Quello che si sta scrivendo.
    var draft = ""
    private(set) var isSaving = false

    init(list: AdminMobileUsersViewModel, user: AdminMobileUser) {
        self.list = list
        self.user = user
        specialties = user.specialties
    }

    var title: String { user.displayName }
    var hasChanges: Bool { specialties != user.specialties }
    var canAdd: Bool { !normalizedDraft.isEmpty && specialties.count < Self.maxCount && !contains(normalizedDraft) }
    /// Anche con un'etichetta ancora nel campo: `save` la aggiunge prima di salvare.
    var canSave: Bool { (hasChanges || canAdd) && !isSaving }

    private var normalizedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func contains(_ value: String) -> Bool {
        specialties.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    /// Un invio nella tastiera: l'etichetta entra e il campo si svuota (anche "a, b" ne aggiunge due).
    func addDraft() {
        for part in draft.split(separator: ",") {
            let value = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, !contains(value), specialties.count < Self.maxCount { specialties.append(value) }
        }
        draft = ""
    }

    func remove(_ specialty: String) {
        specialties.removeAll { $0 == specialty }
    }

    /// Dice se è andata, per chiudere il foglio; l'errore lo mostra la lista.
    func save() async -> Bool {
        addDraft()
        isSaving = true
        defer { isSaving = false }
        return await list.saveSpecialties(user, specialties)
    }
}
