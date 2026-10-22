//
//  AdminMobileUserInviteViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il form "Invite new operator": nome ed email (POST …/mobile-users/invite). Il server manda il link di
//  accesso per email e occupa un posto. L'errore (posti finiti, email già usata) resta nel foglio.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMobileUserInviteViewModel: Identifiable {
    let backend: AriaBackend

    var name = ""
    var email = ""
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(backend: AriaBackend) {
        self.backend = backend
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Controllo leggero: il server fa quello vero.
    var isEmailValid: Bool {
        let parts = trimmedEmail.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !trimmedEmail.contains(" ")
    }

    var canSave: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 100 && isEmailValid && trimmedEmail.count <= 254 && !isSaving
    }

    /// Una riga sotto l'email quando quello che c'è scritto non va.
    var validationMessage: String? {
        guard !trimmedEmail.isEmpty, !isEmailValid else { return nil }
        return String(localized: "Enter a valid email address.")
    }

    func save() async -> AdminMobileUser? {
        guard canSave, let companyId = backend.activeCompanyId else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let body = AdminMobileUserInvite(name: trimmedName, email: trimmedEmail)
            return try await backend.api.call(AdminMobileUsersAPI.invite(companyId: companyId, body))
        } catch {
            errorMessage = AdminMobileUserFailure.message(for: error, backend: backend)
            return nil
        }
    }
}
