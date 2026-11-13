//
//  AdminMemberDetailViewModel+Company.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Il blocco "In azienda" della scheda: ruolo, Lavoro sul campo, nome, qualifica e specialità, sospendere e
//  rimuovere dall'azienda. Ogni pulsante c'è solo dove AdminMemberRules dice che il server lo accetta.
//  Qui stanno anche gli errori comuni a tutta la scheda.
//

import Foundation

extension AdminMemberDetailViewModel {
    // MARK: - Errori e azioni esclusive

    /// Una sola azione sulla persona alla volta.
    func exclusive(_ body: () async -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        await body()
    }

    /// Esegue una scrittura; se riesce rilegge elenco, licenze e persona. Se no, dice perché.
    func attempt(seatLimitText: String? = nil, _ work: () async throws -> Void) async {
        await exclusive {
            do {
                try await work()
                await reloadAfterAction()
            } catch {
                await report(error, seatLimitText: seatLimitText)
            }
        }
    }

    /// Il rifiuto in un avviso. `seatLimitText`: le licenze finite spiegate per quell'azione.
    func report(_ error: any Error, seatLimitText: String? = nil) async {
        guard let failure = AdminMembersFailure.from(error, action: .write, backend: backend) else { return }
        await absorb(failure, text: failure.refusal == .seatLimitReached ? seatLimitText : nil)
    }

    /// Cosa fare di un rifiuto: dirlo e rimettere a posto quel che è cambiato nel frattempo.
    func absorb(_ failure: AdminMembersFailure, text: String? = nil) async {
        if failure.isNotFound {
            await didDisappear()
            return
        }
        actionError = text ?? failure.message
        await refreshAfter(failure)
        // Un rifiuto con un codice dice che lo stato è cambiato: si rilegge.
        if failure.refusal != nil { await reloadAfterAction() }
    }

    /// Il testo di un errore di scrittura per un foglio aperto sulla scheda (nome, qualifica, specialità).
    func message(forWriting error: any Error) async -> String? {
        guard let failure = AdminMembersFailure.from(error, action: .write, backend: backend) else { return nil }
        if failure.isNotFound {
            await didDisappear()
        } else {
            await refreshAfter(failure)
        }
        return failure.message
    }

    /// `escalation_denied` e `permission_denied`: i diritti sono cambiati, si rileggono da /v1/me. `role_not_found`:
    /// si ricaricano i ruoli.
    private func refreshAfter(_ failure: AdminMembersFailure) async {
        if failure.accessRefusal == .escalationDenied || failure.isForbidden { await backend.refreshMembership() }
        if failure.accessRefusal == .roleNotFound { await loadRoles() }
    }

    // MARK: - Ruolo

    var canLoadRoles: Bool { viewer.canManageRoles || viewer.isAdmin }

    func loadRolesIfNeeded() async {
        guard canLoadRoles, !hasLoadedRoles else { return }
        await loadRoles()
    }

    func loadRoles() async {
        guard canLoadRoles, let companyId else { return }
        do {
            roles = try await AdminRolesAPI(api: backend.api, companyId: companyId).roles()
            hasLoadedRoles = true
        } catch {
            // Senza l'elenco non si offre il selettore: la scheda resta com'è.
            _ = AdminMembersFailure.from(error, action: .read, backend: backend)
        }
    }

    /// Le scelte del ruolo per chi guarda; `nil`: niente da scegliere.
    var roleChoice: AdminMemberRoleChoice? {
        guard let member else { return nil }
        return AdminMemberRules.roleChoices(viewer, member, roles: roles)
    }

    /// Il ruolo attuale, a parole.
    var roleValueText: String {
        guard let member else { return "" }
        if member.isOwner { return String(localized: "Owner") }
        if member.isCompanyAdmin { return String(localized: "Admin") }
        return AdminMemberText.clean(member.accessRole?.name) ?? String(localized: "No role")
    }

    func isCurrentRole(_ role: AdminRole) -> Bool { member?.accessRole?.id == role.id }

    /// Un ruolo in pausa si dice: non dà niente a chi lo ha finché non si riattiva.
    func roleTitle(_ role: AdminRole) -> String {
        role.enabled ? role.name : String(localized: "\(role.name) (paused)")
    }

    /// `nil`: nessun ruolo.
    func setRole(_ roleId: String?) async {
        guard let companyId, roleId != member?.accessRole?.id else { return }
        await attempt {
            try await AdminRolesAPI(api: backend.api, companyId: companyId).assign(userId: userId, roleId: roleId)
        }
    }

    // MARK: - Lavoro sul campo, nome, qualifica, specialità

    /// La qualifica (`technician`, `manager`…), a parole.
    var qualificationText: String {
        member?.roleLabel ?? String(localized: "None")
    }

    var canEditProfile: Bool {
        member.map { AdminMemberRules.canEditProfile(viewer, $0) } ?? false
    }

    /// Nome, qualifica e specialità restano chiusi finché "Lavoro sul campo" è spento.
    var profileLocked: Bool {
        member.map(AdminMemberRules.profileFieldsLocked) ?? true
    }

    var canStartEditingProfile: Bool { canEditProfile && !profileLocked && !isWorking }

    /// Il perché dei campi chiusi (solo a chi potrebbe modificarli).
    var profileHint: String? {
        canEditProfile && profileLocked ? String(localized: "Turn on Field work to edit them.") : nil
    }

    var fieldToggle: AdminMemberFieldToggle {
        guard let member else { return .notAllowed }
        return AdminMemberRules.fieldToggle(viewer, member, hasMobileRow: owner.mobileRow(for: userId) != nil)
    }

    var isFieldOn: Bool { member?.isField ?? false }

    var isFieldToggleEnabled: Bool { fieldToggle == .enabled && !isWorking }

    /// Perché l'interruttore è spento (a parole).
    var fieldToggleReason: String? {
        switch fieldToggle {
        case .removeAppAccessFirst: String(localized: "Remove their app access first.")
        case .reactivateFirst: String(localized: "Reactivate them in the company to change this.")
        case .adminOnly: String(localized: "Only an admin can change this.")
        case .enabled, .notAllowed: nil
        }
    }

    func setField(_ on: Bool) async {
        guard fieldToggle == .enabled, on != isFieldOn else { return }
        await attempt {
            _ = try await AdminMembersAPI(api: backend.api).update(userId: userId, AdminMemberUpdate(field: on))
        }
    }

    func startEditingProfile() {
        guard canStartEditingProfile, let member else { return }
        profileForm = AdminMemberProfileFormViewModel(member: member, owner: self)
    }

    /// Il foglio ha salvato: si rilegge tutto.
    func didSaveProfile() async {
        await reloadAfterAction()
    }

    // MARK: - Sospendere e rimuovere

    var isSuspendedInCompany: Bool { member?.isSuspendedInCompany ?? false }

    var canChangeCompanyStatus: Bool {
        member.map { AdminMemberRules.canChangeCompanyStatus(viewer, $0, activeOwners: owner.activeOwners) } ?? false
    }

    var canRemove: Bool {
        member.map { AdminMemberRules.canRemove(viewer, $0, activeOwners: owner.activeOwners) } ?? false
    }

    var showsConfirmation: Bool {
        get { pendingConfirmation != nil }
        set { if !newValue { pendingConfirmation = nil } }
    }

    func askToSuspend() {
        guard canChangeCompanyStatus, let member else { return }
        pendingConfirmation = .suspendInCompany(appWasActive: member.access == .operator)
    }

    func askToRemove() {
        guard canRemove, let member else { return }
        pendingConfirmation = .removeFromCompany(hadApp: member.access?.hasAppAccess == true)
    }

    /// Riattivare in azienda: con le licenze finite il server rifiuta e la persona resta sospesa.
    func reactivate() async {
        guard canChangeCompanyStatus else { return }
        await attempt(seatLimitText: String(localized: "The app seats are full: free a seat and try again.")) {
            _ = try await AdminMembersAPI(api: backend.api).update(userId: userId, AdminMemberUpdate(status: "active"))
        }
    }

    /// Il pulsante del dialogo di conferma.
    func confirm(_ confirmation: AdminMemberConfirmation) async {
        pendingConfirmation = nil
        switch confirmation {
        case .suspendInCompany:
            guard canChangeCompanyStatus else { return }
            await attempt {
                _ = try await AdminMembersAPI(api: backend.api).update(userId: userId, AdminMemberUpdate(status: "suspended"))
            }
        case .removeFromCompany:
            await removeFromCompany()
        case .suspendApp:
            await setAppStatus("suspended")
        case .revokeAccess:
            await revokeAppAccess()
        case .logoutAll:
            await logOutAll()
        case .logoutDevice(let session):
            await logOut(session)
        }
    }

    /// Dopo la rimozione si torna all'elenco, già riletto.
    private func removeFromCompany() async {
        guard canRemove, let companyId else { return }
        await exclusive {
            do {
                try await AdminMembersAPI(api: backend.api).removeFromCompany(companyId: companyId, userId: userId)
                await owner.refresh()
                isGone = true
            } catch {
                await report(error)
            }
        }
    }
}
