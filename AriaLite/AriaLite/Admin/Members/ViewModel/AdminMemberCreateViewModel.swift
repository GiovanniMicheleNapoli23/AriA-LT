//
//  AdminMemberCreateViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il modulo "New person" (POST /v1/users): nome, email, ruolo di Roles & Rights (sempre mandato: senza, il server
//  ne sceglie uno lui), qualifica facoltativa e l'interruttore "Può usare l'app". Dopo la creazione rilegge
//  l'elenco, confronta il ruolo della persona con quello scelto e, se serve, le dà l'accesso all'app e le manda
//  l'email d'invito. Gli esiti da dire a chi crea sono gli `AdminMemberCreationNotice` della scheda.
//

import Foundation
import Observation

@MainActor
@Observable
final class AdminMemberCreateViewModel: Identifiable {
    let owner: AdminMembersViewModel

    // MARK: - Campi

    var name = ""
    var email = ""
    var label: AdminMemberLabel = .none
    /// "Può usare l'app": spento di partenza.
    var wantsApp = false

    /// I ruoli attivi fra cui scegliere (quelli in pausa non si offrono).
    private(set) var roles: [AdminRole] = []
    private(set) var hasLoadedRoles = false
    private(set) var rolesFailure: String?
    private var chosenRoleId: String?
    private var roleChosenByHand = false

    private(set) var isSaving = false
    private(set) var errorMessage: String?

    init(owner: AdminMembersViewModel) {
        self.owner = owner
    }

    // MARK: - Ruolo

    /// Il ruolo scelto. Finché non lo sceglie a mano chi compila, segue la qualifica (come la web): il ruolo base
    /// della qualifica se è attivo, poi il predefinito se è attivo, altrimenti nessuno.
    var roleId: String? {
        get { roleChosenByHand ? chosenRoleId : AdminMemberRules.preselectedRole(roles, label: label.apiValue) }
        set {
            chosenRoleId = newValue
            roleChosenByHand = true
        }
    }

    /// Nessun ruolo attivo: la persona non si può creare finché non ne esiste uno.
    var hasNoActiveRoles: Bool { hasLoadedRoles && roles.isEmpty }

    func loadRoles() async {
        guard let companyId = owner.backend.activeCompanyId else { return }
        do {
            let all = try await AdminRolesAPI(api: owner.backend.api, companyId: companyId).roles()
            roles = all.filter(\.enabled)
            hasLoadedRoles = true
            rolesFailure = nil
            // Un ruolo scelto che non c'è più: si torna alla preselezione.
            if roleChosenByHand, let chosenRoleId, !roles.contains(where: { $0.id == chosenRoleId }) {
                self.chosenRoleId = nil
                roleChosenByHand = false
            }
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .read, backend: owner.backend) {
                rolesFailure = failure.message
            }
        }
    }

    // MARK: - Presentazione

    var seatsText: String? { owner.seatsText }

    /// Se le licenze sono finite l'interruttore è spento e disattivato.
    var appToggleEnabled: Bool { !owner.seatsAreFull }

    /// L'interruttore come lo vede chi compila: mai acceso con le licenze finite.
    var wantsAppEffective: Bool { wantsApp && appToggleEnabled }

    /// La spiegazione sotto l'interruttore.
    var appFootnote: String {
        if !appToggleEnabled {
            return String(localized: "The app seats are full. Free a seat to give app access, or add them without it.")
        }
        return String(localized: "They get app access and an email with a sign-in link. Owners and admins don't need a seat.")
    }

    /// L'email (senza maiuscole e spazi) è già nell'elenco caricato: si avvisa prima di salvare. "Crea" resta
    /// attivo (chi è sospeso, o non compare per altri motivi, lo decide il server).
    var duplicate: AdminMember? {
        let key = Self.normalizedEmail(email)
        guard !key.isEmpty else { return nil }
        return owner.members.first { Self.normalizedEmail($0.email) == key }
    }

    var canSave: Bool {
        !isSaving && Self.isValidName(trimmedName) && Self.isPlausibleEmail(trimmedEmail) && roleId != nil
    }

    /// Qualcosa è stato scritto: chiudere con un trascinamento lo perderebbe.
    var hasChanges: Bool { !trimmedName.isEmpty || !trimmedEmail.isEmpty }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private static func normalizedEmail(_ text: String) -> String {
        String(text.lowercased().filter { !$0.isWhitespace })
    }

    /// Nome obbligatorio, 1-100 caratteri.
    static func isValidName(_ text: String) -> Bool { (1...100).contains(text.count) }

    /// Controllo leggero: qualcosa@dominio.estensione, senza spazi. Il resto lo decide il server.
    static func isPlausibleEmail(_ text: String) -> Bool {
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !text.contains(where: \.isWhitespace) else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }

    /// Dal foglio alla scheda di chi c'è già nell'elenco.
    func openDuplicate() {
        guard let duplicate else { return }
        owner.open(duplicate.id)
    }

    // MARK: - Salvataggio

    /// Crea la persona. `nil` se non è stata creata (il motivo è in `errorMessage` e il modulo resta aperto).
    /// Se è creata, chiude il foglio e apre la sua scheda: gli esiti parziali sono avvisi della scheda, non errori.
    @discardableResult
    func save() async -> AdminMemberCreationResult? {
        guard canSave, let roleId else { return nil }
        errorMessage = nil
        let wantsApp = wantsAppEffective
        let backend = owner.backend
        isSaving = true
        defer { isSaving = false }

        let body = AdminMemberUserCreate(email: trimmedEmail, fullName: trimmedName, role: label.apiValue,
                                         accessRoleId: roleId)
        let created: AdminMemberCreated
        do {
            created = try await AdminMembersAPI(api: backend.api).createUser(body)
        } catch {
            if let failure = AdminMembersFailure.from(error, action: .write, backend: backend) {
                errorMessage = failure.message
                // Un ruolo tolto nel frattempo: si ricaricano i ruoli.
                if failure.accessRefusal == .roleNotFound { await loadRoles() }
            }
            return nil
        }

        // La risposta non ha ruolo né stato: si rilegge l'elenco e si trova la persona per id.
        await owner.refresh()
        let person = owner.members.first { $0.id == created.id }
        var notices = roleNotices(for: person, chosen: roleId)
        if wantsApp {
            notices += await giveAppAccess(to: created.id, person: person)
            // Licenze e badge dopo l'accesso dato.
            await owner.refresh()
        }

        let result = AdminMemberCreationResult(userId: created.id, notices: notices)
        owner.didCreate(result)
        return result
    }

    /// Il confronto fra il ruolo della persona e quello scelto: con un'email già in azienda il server non lo cambia.
    private func roleNotices(for person: AdminMember?, chosen roleId: String) -> [AdminMemberCreationNotice] {
        guard let person else { return [] }
        if person.isOwnerOrAdmin { return [.alreadyOwnerOrAdmin] }
        guard let role = person.accessRole else { return [.noRoleChooseOne] }
        return role.id == roleId ? [] : [.roleUnchanged]
    }

    /// `POST …/mobile-users`, poi l'email d'invito. Titolari e admin e sospesi in azienda si saltano. Se la
    /// persona non si trova nell'elenco si prova: il server rifiuta con un codice e il motivo si dice.
    private func giveAppAccess(to userId: String, person: AdminMember?) async -> [AdminMemberCreationNotice] {
        if person?.isOwnerOrAdmin == true { return [.appSkippedOwnerOrAdmin] }
        if person?.isSuspendedInCompany == true { return [.appSkippedSuspended] }
        let backend = owner.backend
        guard let companyId = backend.activeCompanyId else {
            return [.appNotGiven(AriaError.missingCompany.localizedDescription)]
        }
        do {
            let _: AdminMobileUser = try await backend.api.call(
                AdminMobileUsersAPI.add(companyId: companyId, AdminMobileUserAdd(userId: userId)))
        } catch {
            let message = AdminMembersFailure.from(error, action: .write, backend: backend)?.message
                ?? error.localizedDescription
            return [.appNotGiven(message)]
        }
        do {
            let sent = try await backend.api.auth.sendMobileInviteLink(companyId: companyId, userId: userId)
            return sent ? [] : [.emailNotSent]
        } catch {
            // Una sessione scaduta passa da `backend.handle`; per il resto basta dire che l'email non è partita.
            _ = AdminMembersFailure.from(error, action: .write, backend: backend)
            return [.emailNotSent]
        }
    }
}
