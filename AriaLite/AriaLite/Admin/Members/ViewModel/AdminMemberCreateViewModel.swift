//
//  AdminMemberCreateViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "Add member" (POST /v1/users): email, nome, ruolo e password. Solo l'email è obbligatoria per
//  il server; nome, ruolo e password vuoti non si mandano. L'email si controlla qui, in modo leggero.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemberCreateViewModel: Identifiable {
    let owner: AdminMembersViewModel

    // MARK: - Campi

    var email = ""
    var fullName = ""
    var role = ""
    var password = ""

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(owner: AdminMembersViewModel) {
        self.owner = owner
    }

    // MARK: - Presentazione

    var roleSuggestions: [String] { owner.roleSuggestions }

    func roleLabel(_ raw: String) -> String { AdminMemberRole.label(raw) }

    /// Il suggerimento è il ruolo scritto (ruoli uguali a meno delle maiuscole).
    func isCurrentRole(_ raw: String) -> Bool {
        AdminMemberRole.key(raw) == AdminMemberRole.key(trimmed(role))
    }

    var canSave: Bool { !isSaving && !trimmed(email).isEmpty }

    /// Qualcosa è stato scritto: chiudere con un trascinamento lo perderebbe.
    var hasChanges: Bool {
        ![email, fullName, role, password].allSatisfy { trimmed($0).isEmpty }
    }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func optional(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }

    /// Controllo leggero: qualcosa@dominio.estensione, senza spazi. Il resto lo decide il server.
    static func isPlausibleEmail(_ text: String) -> Bool {
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !text.contains(where: \.isWhitespace) else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }

    // MARK: - Salvataggio

    /// `true` se creato: il modulo si può chiudere.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        guard Self.isPlausibleEmail(trimmed(email)) else {
            errorMessage = String(localized: "Enter a valid email address.")
            return false
        }
        // La password non si taglia: gli spazi ai lati potrebbero essere voluti.
        let body = AdminMemberUserCreate(
            email: trimmed(email), fullName: optional(fullName),
            password: password.isEmpty ? nil : password, role: optional(role)
        )
        isSaving = true
        defer { isSaving = false }
        do {
            try await AdminMembersAPI(api: owner.backend.api).createUser(body)
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .write, backend: owner.backend) {
                errorMessage = failure.message
            }
            return false
        }
        await owner.didCreateMember()
        return true
    }
}
