//
//  AdminMemberProfileFormViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il foglio con nome, qualifica e specialità di una persona (PATCH /v1/members/{id}): si manda solo quel che
//  è cambiato. Si apre solo con "Lavoro sul campo" acceso; il salvataggio lo racconta la scheda.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemberProfileFormViewModel: Identifiable {
    static let maxNameLength = 100
    static let maxSpecialties = 100

    let owner: AdminMemberDetailViewModel
    let member: AdminMember

    var name: String
    /// Il valore della qualifica: vuoto, `technician`, `manager` o un testo vecchio già in azienda.
    var label: String
    private(set) var specialties: [String]
    /// La qualifica di partenza, con le maiuscole del server ricondotte all'elenco ("Technician" → `technician`).
    private let initialLabel: String
    /// Quello che si sta scrivendo.
    var draft = ""
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(member: AdminMember, owner: AdminMemberDetailViewModel) {
        self.member = member
        self.owner = owner
        name = member.fullName ?? ""
        let current = member.role ?? ""
        let initial = AdminMemberLabel(rawValue: current.lowercased())?.rawValue ?? current
        initialLabel = initial
        label = initial
        specialties = member.specialties
    }

    // MARK: - Presentazione

    /// Le qualifiche fra cui scegliere; una vecchia, già salvata e fuori elenco, resta scelta finché non si cambia.
    var labelChoices: [(value: String, title: String)] {
        var choices = AdminMemberLabel.allCases.map { (value: $0.rawValue, title: $0.title) }
        if !choices.contains(where: { $0.value == initialLabel }) {
            choices.append((value: initialLabel, title: AdminMemberRole.label(initialLabel)))
        }
        return choices
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func contains(_ value: String) -> Bool {
        specialties.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
    }

    var nameIsValid: Bool { (1...Self.maxNameLength).contains(trimmedName.count) }
    var canAdd: Bool { !normalizedDraft.isEmpty && specialties.count < Self.maxSpecialties && !contains(normalizedDraft) }

    /// Cosa è cambiato, nel body del PATCH (`nil`: niente).
    private var update: AdminMemberUpdate? {
        var body = AdminMemberUpdate()
        if trimmedName != (member.fullName ?? "") { body.name = trimmedName }
        if label != initialLabel { body.label = label }
        if specialtiesWithDraft != member.specialties { body.specialties = specialtiesWithDraft }
        let isEmpty = body.name == nil && body.label == nil && body.specialties == nil
        return isEmpty ? nil : body
    }

    /// Un'etichetta ancora nel campo entra comunque nel salvataggio.
    private var specialtiesWithDraft: [String] {
        var result = specialties
        for part in draft.split(separator: ",") {
            let value = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty, !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }),
               result.count < Self.maxSpecialties {
                result.append(value)
            }
        }
        return result
    }

    var hasChanges: Bool { update != nil }
    var canSave: Bool { hasChanges && nameIsValid && !isSaving }

    // MARK: - Specialità

    /// Un invio nella tastiera: l'etichetta entra e il campo si svuota (anche "a, b" ne aggiunge due).
    func addDraft() {
        specialties = specialtiesWithDraft
        draft = ""
    }

    func remove(_ specialty: String) {
        specialties.removeAll { $0 == specialty }
    }

    // MARK: - Salvataggio

    /// `true` se salvato: il foglio si può chiudere.
    func save() async -> Bool {
        guard canSave, let body = update else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await AdminMembersAPI(api: owner.backend.api).update(userId: member.id, body)
        } catch {
            errorMessage = await owner.message(forWriting: error)
            return false
        }
        await owner.didSaveProfile()
        return true
    }
}
