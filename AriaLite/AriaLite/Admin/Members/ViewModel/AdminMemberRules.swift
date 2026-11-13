//
//  AdminMemberRules.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Tutte le decisioni di Members in funzioni pure: chi può fare cosa (§6.5), le scelte del ruolo (§6.4), lo stato
//  dell'accesso all'app e le sue azioni, i badge dell'elenco. Niente rete: si prova con persone decodificate da JSON.
//

import Foundation

nonisolated enum AdminMemberRules {
    // MARK: - Chi può fare cosa

    /// Chi guarda raggiunge questa persona: l'admin sempre; un ruolo solo un `member` con ruolo Low o senza ruolo
    /// (mai titolari, admin o ruoli High: 403 `escalation_denied`).
    static func reaches(_ viewer: AdminPeopleViewer, _ member: AdminMember) -> Bool {
        if viewer.isAdmin { return true }
        return member.access != nil && member.isRegularMember && member.accessRole?.set != "high"
    }

    static func canCreate(_ viewer: AdminPeopleViewer) -> Bool { viewer.isAdmin }

    /// Nome, qualifica, specialità, lavoro sul campo.
    static func canEditProfile(_ viewer: AdminPeopleViewer, _ member: AdminMember) -> Bool {
        member.access != nil
            && (viewer.isAdmin || (viewer.rights.can(.edit, in: .members) && reaches(viewer, member)))
    }

    /// Nome, qualifica e specialità si cambiano solo se lavora sul campo (altrimenti 409 `not_a_field_worker`).
    static func profileFieldsLocked(_ member: AdminMember) -> Bool { !member.isField }

    static func canAssignShifts(_ viewer: AdminPeopleViewer, _ member: AdminMember) -> Bool {
        viewer.isAdmin || (viewer.rights.can(.assignShifts, in: .members) && reaches(viewer, member))
    }

    /// Sospendere o riattivare in azienda. Mai su se stessi (e senza sapere chi si è, su nessuno); lo stato di un
    /// titolare lo cambia solo un titolare, e l'ultimo titolare attivo non si sospende.
    static func canChangeCompanyStatus(_ viewer: AdminPeopleViewer, _ member: AdminMember, activeOwners: Int) -> Bool {
        guard viewer.isAdmin, isAnotherPerson(viewer, member), member.access != nil else { return false }
        if member.isOwner {
            guard viewer.isOwner else { return false }
            return member.isSuspendedInCompany || activeOwners > 1
        }
        return true
    }

    /// Rimuovere dall'azienda. Mai se stessi; un admin non rimuove un titolare; nessuno rimuove l'ultimo titolare.
    static func canRemove(_ viewer: AdminPeopleViewer, _ member: AdminMember, activeOwners: Int) -> Bool {
        guard viewer.isAdmin, isAnotherPerson(viewer, member), member.access != nil else { return false }
        if member.isOwner { return viewer.isOwner && activeOwners > 1 }
        return true
    }

    private static func isAnotherPerson(_ viewer: AdminPeopleViewer, _ member: AdminMember) -> Bool {
        guard let userId = viewer.userId else { return false }
        return userId != member.id
    }

    // MARK: - Ruolo

    /// Le scelte del ruolo, come la web (`memberRoleOptions`); `nil` se non c'è niente da scegliere.
    static func roleChoices(_ viewer: AdminPeopleViewer, _ member: AdminMember, roles: [AdminRole]) -> AdminMemberRoleChoice? {
        guard viewer.canManageRoles || viewer.isAdmin, member.isRegularMember, member.access != nil else { return nil }
        if viewer.isAdmin {
            return AdminMemberRoleChoice(options: roles, canUnassign: member.accessRole != nil)
        }
        // Ruolo alto: solo i ruoli Low che il suo ruolo ha creato, e niente se la persona ha un ruolo High.
        guard let ownRoleId = viewer.ownRoleId, member.accessRole?.set != "high" else { return nil }
        let options = roles.filter { $0.set == .low && $0.ownerRoleId == ownRoleId }
        let canUnassign = member.accessRole.map { current in options.contains { $0.id == current.id } } ?? false
        guard !options.isEmpty || canUnassign else { return nil }
        return AdminMemberRoleChoice(options: options, canUnassign: canUnassign)
    }

    /// La preselezione del ruolo nella creazione (`newMemberRolePreselect` della web): il ruolo base della qualifica
    /// se è attivo, poi il predefinito se è attivo, altrimenti nessuno.
    static func preselectedRole(_ roles: [AdminRole], label: String?) -> String? {
        if let label, !label.isEmpty, let seeded = roles.first(where: { $0.enabled && $0.seedKey == label }) {
            return seeded.id
        }
        return roles.first { $0.enabled && $0.isDefault }?.id
    }

    /// La riga sotto il nome: "Owner", "Admin", il ruolo, o "Needs a role" (solo a chi può dare ruoli).
    static func roleLine(_ member: AdminMember, viewerCanManageRoles: Bool) -> String? {
        if member.isOwner { return String(localized: "Owner") }
        if member.isCompanyAdmin { return String(localized: "Admin") }
        if let name = AdminMemberText.clean(member.accessRole?.name) { return name }
        // Un record senza membership (legacy) non prende ruoli: niente "serve un ruolo".
        return viewerCanManageRoles && member.access != nil ? String(localized: "Needs a role") : nil
    }

    // MARK: - Accesso all'app

    /// Lo stato dell'app. Con la persona sospesa in azienda la riga mobile dice sempre `suspended` (anche se era
    /// revocata): non si legge. Una riga revocata, o nessuna riga, si legge da `access`.
    static func appAccessState(_ member: AdminMember, row: AdminMobileUser?) -> AdminAppAccessState {
        if member.isOwnerOrAdmin { return .ownerOrAdmin }
        if member.access == .suspended { return .companySuspended(hasRow: row != nil) }
        guard let row, let status = row.knownStatus, status != .revoked else {
            switch member.access {
            case .operator?: return .active(availability: "")
            case .operatorInvited?: return .invited(until: nil)
            case .operatorSuspended?: return .appSuspended
            default: return .none
            }
        }
        switch status {
        case .invited: return .invited(until: row.invitedUntil)
        case .expired: return .expired(on: row.invitedUntil)
        case .active: return .active(availability: row.availability)
        case .suspended: return .appSuspended
        case .revoked: return .none
        }
    }

    /// Le azioni della tabella del §6.4. Chi prenderebbe una licenza è disattivato a licenze finite.
    static func appOffers(_ state: AdminAppAccessState, seats: AdminMobileUserSeats?) -> [AdminAppAccessOffer] {
        let hasSeat = !(seats?.isFull ?? false)
        switch state {
        case .ownerOrAdmin, .companySuspended(hasRow: false): return []
        case .companySuspended(hasRow: true): return [.init(action: .revokeAccess, isEnabled: true)]
        case .none: return [.init(action: .giveAccess, isEnabled: hasSeat)]
        case .invited:
            return [.init(action: .resendInvite, isEnabled: true), .init(action: .revokeAccess, isEnabled: true)]
        case .expired:
            return [.init(action: .renewAndResend, isEnabled: hasSeat), .init(action: .revokeAccess, isEnabled: true)]
        case .active:
            return [.init(action: .suspendApp, isEnabled: true), .init(action: .revokeAccess, isEnabled: true)]
        case .appSuspended:
            return [.init(action: .reactivateApp, isEnabled: hasSeat), .init(action: .revokeAccess, isEnabled: true)]
        }
    }

    /// La persona occupa una licenza adesso: app attiva o invito non scaduto, con la persona attiva in azienda.
    static func holdsSeat(_ member: AdminMember, row: AdminMobileUser?) -> Bool {
        guard !member.isSuspendedInCompany, let status = row?.knownStatus else { return false }
        return status == .active || status == .invited
    }

    /// L'interruttore "Lavoro sul campo".
    static func fieldToggle(_ viewer: AdminPeopleViewer, _ member: AdminMember, hasMobileRow: Bool) -> AdminMemberFieldToggle {
        guard canEditProfile(viewer, member) else { return .notAllowed }
        if member.access?.hasAppAccess == true { return .removeAppAccessFirst }
        if member.isSuspendedInCompany {
            if !viewer.isAdmin { return .adminOnly }
            if hasMobileRow { return .reactivateFirst }
        }
        return .enabled
    }

    // MARK: - Elenco

    /// Il badge dell'elenco, da `access` (§6.2); l'invito scaduto lo dice la riga mobile.
    static func badge(_ member: AdminMember, row: AdminMobileUser?) -> AdminMemberBadgeKind? {
        guard let access = member.access else { return nil }
        switch access {
        case .suspended:
            return .companySuspended
        case .operatorInvited:
            return row?.knownStatus == .expired ? AdminMemberBadgeKind.appInviteExpired : AdminMemberBadgeKind.appInvited
        case .operatorSuspended:
            return .appSuspended
        case .operator:
            return .appActive
        case .owner, .admin, .member:
            return nil
        }
    }
}
