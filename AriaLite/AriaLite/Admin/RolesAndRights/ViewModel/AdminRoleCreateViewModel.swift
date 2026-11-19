//
//  AdminRoleCreateViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il modulo "Nuovo ruolo" ("Nuovo ruolo base" per un ruolo alto): nome obbligatorio (60 caratteri al più) e, solo
//  per owner e admin, il livello. Si crea senza sezioni; un nome già usato resta sotto il campo.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminRoleCreateViewModel: Identifiable {
    let owner: AdminRolesViewModel

    nonisolated static let nameLimit = 60

    var name = "" {
        didSet {
            if name.count > Self.nameLimit { name = String(name.prefix(Self.nameLimit)) }
            if name != oldValue { nameError = nil }
        }
    }
    var level: AdminRoleSet = .low
    private(set) var nameError: String?
    private(set) var errorMessage: String?
    private(set) var isSaving = false

    init(owner: AdminRolesViewModel) {
        self.owner = owner
    }

    /// Owner e admin scelgono il livello; un ruolo alto crea sempre ruoli base.
    var asksLevel: Bool { owner.isAdmin }
    var isLow: Bool { owner.isHighHolder }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSubmit: Bool { !isSaving && !trimmedName.isEmpty }

    /// `true`: creato, il modulo si chiude (e il ruolo nuovo è già aperto).
    func submit() async -> Bool {
        guard canSubmit else { return false }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        switch await owner.create(name: trimmedName, set: level) {
        case .done: return true
        case .nameTaken: nameError = AriaAccessRefusal.roleNameTaken.localized
        case .failed(let message): errorMessage = message
        case .hasMembers: break
        }
        return false
    }
}
