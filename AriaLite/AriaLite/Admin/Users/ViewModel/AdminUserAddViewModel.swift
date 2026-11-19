//
//  AdminUserAddViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il modulo "Add a person" (§6.1, §6.2): nome, email, etichetta e livello. Due chiamate: POST /v1/users aggiunge la
//  persona, poi l'email d'invito dal sito. Se l'email non parte la persona resta aggiunta e lo si dice; se l'aggiunta
//  è rifiutata il modulo resta aperto con il motivo. Dopo ogni esito si rilegge l'elenco e il tetto.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminUserAddViewModel: Identifiable {
    let owner: AdminUsersViewModel

    nonisolated static let nameLimit = 100

    /// L'etichetta: `role` del body, non il livello.
    enum PersonLabel: String, CaseIterable, Identifiable {
        case technician
        case manager

        var id: String { rawValue }

        var title: String {
            switch self {
            case .technician: String(localized: "Technician")
            case .manager: String(localized: "Manager")
            }
        }
    }

    /// Un gruppo di voci del livello, con il titolo della sezione ("High roles", "Low roles") o senza.
    struct LevelGroup: Identifiable {
        let title: String?
        let options: [AdminUserLevelOption]
        var id: String { title ?? options.first?.title ?? "-" }
    }

    var name = "" {
        didSet { if name.count > Self.nameLimit { name = String(name.prefix(Self.nameLimit)) } }
    }
    var email = "" {
        didSet { if email != oldValue { emailError = nil } }
    }
    var label: PersonLabel = .technician

    private var chosenLevel: AdminUserLevelValue?

    private(set) var emailError: String?
    /// Il rifiuto del server, sotto i campi.
    private(set) var errorMessage: String?
    private(set) var isSubmitting = false

    init(owner: AdminUsersViewModel) {
        self.owner = owner
    }

    // MARK: - Livello (§6.1)

    private var legacy: Bool { owner.viewer.legacy }

    /// Le voci del selettore: Owner (spento al tetto), i ruoli attivi, "No role" o "Member".
    var levelOptions: [AdminUserLevelOption] {
        AdminUsersRules.addLevelOptions(page: owner.page ?? AdminUsersPage(), roles: owner.roles, legacy: legacy)
    }

    var levelGroups: [LevelGroup] {
        let options = levelOptions
        func group(_ title: String?, _ kind: AdminUserLevelOption.Group...) -> LevelGroup? {
            let items = options.filter { kind.contains($0.group) }
            return items.isEmpty ? nil : LevelGroup(title: title, options: items)
        }
        return [group(nil, .owner), group(String(localized: "High roles"), .high),
                group(String(localized: "Low roles"), .low), group(nil, .none)].compactMap(\.self)
    }

    /// Il livello scelto; finché chi compila non sceglie, segue il ruolo predefinito (se attivo) o nessuno.
    /// Una scelta che non c'è più fra le voci (un ruolo messo in pausa) torna alla scelta di partenza.
    var level: AdminUserLevelValue {
        get {
            if let chosenLevel, levelOptions.contains(where: { $0.value == chosenLevel && !$0.isDisabled }) {
                return chosenLevel
            }
            return AdminUsersRules.addPreselect(roles: owner.roles, legacy: legacy)
        }
        set { chosenLevel = newValue }
    }

    var levelTitle: String {
        levelOptions.first { $0.value == level }?.title ?? AdminUsersRules.noRoleTitle(legacy: legacy)
    }

    /// "An owner holds every section and can make or remove owners."
    var ownerHint: String? {
        level == .owner ? String(localized: "An owner holds every section and can make or remove owners.") : nil
    }

    /// Chi apre il modulo prima che i ruoli siano arrivati li aspetta.
    func loadRolesIfNeeded() async {
        if !owner.hasLoadedRoles && owner.needsRoles { await owner.loadRoles() }
    }

    // MARK: - Invio

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSubmit: Bool { !isSubmitting && !trimmedName.isEmpty && !trimmedEmail.isEmpty }

    /// Ci sono dati scritti: chiudere il foglio con un gesto chiede prima.
    var hasChanges: Bool { !trimmedName.isEmpty || !trimmedEmail.isEmpty }

    /// `true`: la persona è stata aggiunta (con o senza email) e il foglio si chiude.
    func submit() async -> Bool {
        guard canSubmit, let api = owner.api, let companyId = owner.companyId else { return false }
        guard AdminUsersRules.isValidEmail(email) else {
            emailError = String(localized: "Enter a valid email address.")
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        let fullName = trimmedName
        let created: AdminMemberCreated
        do {
            let body = AdminUsersRules.createBody(name: fullName, email: email, label: label.rawValue, level: level)
            created = try await api.create(body)
        } catch {
            // `nil`: annullata o sessione scaduta, non si dice niente. Il tetto pieno lo rilegge `absorb`.
            guard let failure = AdminUsersFailure.from(error, backend: owner.backend) else { return false }
            errorMessage = failure.message
            await owner.absorb(failure)
            return false
        }
        let sent = await sendEmail(companyId: companyId, userId: created.id)
        owner.show(sent
                   ? String(localized: "\(fullName) was added and emailed.")
                   : String(localized: "\(fullName) was added, but the email didn't go out. Use Resend email."))
        await owner.afterWrite()
        return true
    }

    /// L'email d'invito dal sito: un errore o `false` vale "non partita", la persona resta aggiunta.
    private func sendEmail(companyId: String, userId: String) async -> Bool {
        do {
            return try await owner.backend.api.auth.sendMobileInviteLink(companyId: companyId, userId: userId)
        } catch {
            _ = AdminUsersFailure.from(error, backend: owner.backend)
            return false
        }
    }
}
