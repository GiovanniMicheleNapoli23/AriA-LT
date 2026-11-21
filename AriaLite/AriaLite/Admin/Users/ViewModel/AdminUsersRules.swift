//
//  AdminUsersRules.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le decisioni della sezione Users in funzioni pure, come `lib/users/rules.ts` della web: chi apre la sezione (§2),
//  le voci del livello (§5.2), cosa mostra la scheda (§5, §7), il livello in "Add user" (§6.1), il tetto (§6.4).
//  Niente rete: si prova con righe e ruoli costruiti nei test. Il server resta l'autorità.
//

import Foundation

nonisolated enum AdminUsersRules {
    // MARK: - Chi apre la sezione (§2)

    enum Entry: Equatable {
        /// `/v1/me` non ha ancora risposto: si aspetta, mai "nessun accesso".
        case loading
        case open
        case hidden
    }

    /// Titolare (`access.admin`), oppure un membro con la sezione Members in un'azienda a ruoli la cui app segue il ruolo.
    static func entry(_ access: AriaAccess?) -> Entry {
        guard let access else { return .loading }
        if access.admin { return .open }
        let members = access.sections[AriaSection.members.rawValue]?.granted == true
        return access.model == "rbac" && access.appFollowsRole && members ? .open : .hidden
    }

    // MARK: - Le viste della sezione (Users e Roles)

    /// La vista Users: la regola del §2 (mentre `/v1/me` non ha risposto si apre); nel layout dell'operatore il ruolo
    /// deve concedere anche Members.
    static func usersViewOpen(_ rights: AriaRights, operatorLayout: Bool) -> Bool {
        entry(rights.access) != .hidden && (!operatorLayout || rights.has(.members))
    }

    /// La vista Roles: chi gestisce i ruoli in un'azienda a ruoli (l'ex sezione Roles & Rights).
    static func rolesViewOpen(_ rights: AriaRights) -> Bool { rights.canOpenRolesAndRights }

    /// Le viste che si possono aprire, nell'ordine in cui si mostrano.
    static func tabs(usersOpen: Bool, rolesOpen: Bool) -> [AdminUsersTab] {
        [usersOpen ? .users : nil, rolesOpen ? .roles : nil].compactMap { $0 }
    }

    /// La vista mostrata: quella scelta se si può aprire, altrimenti la prima che si può.
    static func current(selected: AdminUsersTab, in tabs: [AdminUsersTab]) -> AdminUsersTab {
        tabs.contains(selected) ? selected : tabs.first ?? .users
    }

    // MARK: - Titolari

    /// Un titolare non sospeso (anche invitato: la sua membership è attiva).
    static func isActiveOwner(_ row: AdminUserRow) -> Bool { row.isOwner && row.status != .suspended }

    static func isLastActiveOwner(_ row: AdminUserRow, in people: [AdminUserRow]) -> Bool {
        isActiveOwner(row) && people.filter(isActiveOwner).count == 1
    }

    static func ownersFull(_ page: AdminUsersPage) -> Bool { page.owners.count >= page.owners.max }

    // MARK: - Il livello (§5.2)

    static func currentLevel(_ row: AdminUserRow) -> AdminUserLevelValue {
        if row.isOwner { return .owner }
        return row.role.map { .role($0.id) } ?? .none
    }

    /// "{name} (paused)" per un ruolo in pausa.
    static func roleTitle(name: String, enabled: Bool) -> String {
        enabled ? name : String(localized: "\(name) (paused)")
    }

    /// "Owner", "No role" o "Member".
    static func noRoleTitle(legacy: Bool) -> String {
        legacy ? String(localized: "Member") : String(localized: "No role")
    }

    private static func option(_ role: AdminRole) -> AdminUserLevelOption {
        AdminUserLevelOption(value: .role(role.id), group: role.set == .high ? .high : .low,
                             title: roleTitle(name: role.name, enabled: role.enabled))
    }

    /// Le voci del selettore, nell'ordine: Owner, i ruoli alti, i ruoli bassi, No role. `nil`: niente selettore
    /// (il livello si mostra come testo).
    static func levelOptions(for row: AdminUserRow, page: AdminUsersPage, roles: [AdminRole],
                             viewer: AdminUsersViewer) -> [AdminUserLevelOption]? {
        switch viewer.kind {
        case .owner:
            let owner = AdminUserLevelOption(value: .owner, group: .owner, title: String(localized: "Owner"))
            let none = AdminUserLevelOption(value: .none, group: .none, title: noRoleTitle(legacy: viewer.legacy))
            let all = viewer.legacy
                ? [owner, none]
                : [owner] + roles.filter { $0.set == .high }.map(option) + roles.filter { $0.set == .low }.map(option) + [none]
            let atCap = ownersFull(page) && !row.isOwner
            let lastOwner = isLastActiveOwner(row, in: page.people)
            return all.map { item in
                var item = item
                if item.group == .owner {
                    if atCap { item.isDisabled = true; item.hint = .ownerCap }
                } else if lastOwner {
                    item.isDisabled = true
                    item.hint = .lastOwner
                }
                return item
            }
        case .highHolder:
            // Solo i ruoli bassi creati dal suo ruolo, per chi ha un ruolo basso o nessuno.
            guard !viewer.legacy, !row.isOwner, row.role?.isHigh != true else { return nil }
            let own = roles.filter { $0.set == .low && $0.ownerRoleId != nil && $0.ownerRoleId == viewer.ownRoleId }
            var options = own.map(option)
            // Un ruolo che non dà lui resta visibile come valore attuale, disattivato.
            if let current = row.role, !own.contains(where: { $0.id == current.id }) {
                var item = AdminUserLevelOption(value: .role(current.id), group: .low,
                                                title: roleTitle(name: current.name, enabled: current.enabled))
                item.isDisabled = true
                options.insert(item, at: 0)
            }
            // No role: il valore attuale di chi non ne ha, o togliere un ruolo che dà lui.
            if row.role == nil || own.contains(where: { $0.id == row.role?.id }) {
                options.append(AdminUserLevelOption(value: .none, group: .none, title: String(localized: "No role")))
            }
            return options.isEmpty ? nil : options
        case .otherHolder:
            return nil
        }
    }

    /// Il ruolo predefinito se è attivo; altrimenti nessuno.
    static func demotionPreselect(_ roles: [AdminRole]) -> String? {
        guard let preferred = roles.first(where: \.isDefault), preferred.enabled else { return nil }
        return preferred.id
    }

    /// Cosa succede scegliendo `target` nel selettore del livello.
    enum LevelStep: Equatable {
        /// Lo stesso valore: niente.
        case nothing
        /// Fra ruoli (o nessun ruolo): si manda subito.
        case send(AdminUserLevelChange)
        /// Diventa titolare: conferma "Make {name} an owner?" (con il ruolo che perde, se ne ha uno).
        case confirmPromotion(losingRole: String?)
        /// Un titolare lascia: prima la scelta del nuovo ruolo (che parte dal predefinito attivo o da nessuno),
        /// poi la conferma; su se stessi "Step down" e si manda senza seconda conferma.
        case chooseDemotionRole(preselect: String?, isSelf: Bool)
        /// Azienda senza ruoli: conferma "Remove {name} as an owner?" · "{name} will no longer be an owner."
        case confirmLegacyDemotion
    }

    static func levelStep(from row: AdminUserRow, to target: AdminUserLevelValue, roles: [AdminRole],
                          viewer: AdminUsersViewer) -> LevelStep {
        let current = currentLevel(row)
        if current == target { return .nothing }
        switch (current, target) {
        case (_, .owner):
            return .confirmPromotion(losingRole: row.role?.name)
        case (.owner, _):
            if viewer.legacy { return .confirmLegacyDemotion }
            return .chooseDemotionRole(preselect: demotionPreselect(roles), isSelf: viewer.isSelf(row))
        default:
            return .send(.member(roleId: target.roleId))
        }
    }

    /// Il livello come testo, per chi non ha il selettore: "Owner", il ruolo, "No role" ("Member").
    static func levelText(_ row: AdminUserRow, legacy: Bool) -> String {
        if row.isOwner { return String(localized: "Owner") }
        if let role = row.role { return role.name }
        return noRoleTitle(legacy: legacy)
    }

    /// Il badge del livello nella riga: come `levelText`, con "{role} · paused" per un ruolo in pausa.
    static func levelBadge(_ row: AdminUserRow, legacy: Bool) -> String {
        if let role = row.role, !row.isOwner, !role.enabled { return String(localized: "\(role.name) · paused") }
        return levelText(row, legacy: legacy)
    }

    // MARK: - La scheda (§5, §7)

    /// Cosa mostra la scheda Accesso a chi guarda; il livello c'è sempre (selettore o testo).
    struct AccessControls: Equatable {
        var appSwitch = false
        /// L'interruttore dell'app è spento su se stessi: "You can't turn off your own app access."
        var appSwitchLockedOnSelf = false
        var fieldSwitch = false
        var specialties = false
        var assignWorkOrder = false
        var sessions = false
        var resendEmail = false
        var suspend = false
        var reactivate = false
        var remove = false
    }

    static func accessControls(for row: AdminUserRow, viewer: AdminUsersViewer) -> AccessControls {
        guard viewer.isOwner else { return AccessControls() }
        let isSelf = viewer.isSelf(row)
        // Senza sapere chi si è, mai le azioni di stato: potrebbe essere se stessi.
        let other = viewer.userId != nil && !isSelf
        return AccessControls(
            appSwitch: true,
            appSwitchLockedOnSelf: isSelf,
            fieldSwitch: true,
            specialties: row.fieldWorker,
            assignWorkOrder: row.fieldWorker && row.status == .active,
            sessions: true,
            resendEmail: row.status == .invited,
            suspend: other && row.status != .suspended,
            reactivate: other && row.status == .suspended,
            remove: other)
    }

    /// Le schede della persona: Schedule solo con `assign_shifts` (o titolare).
    static func showsSchedule(_ viewer: AdminUsersViewer) -> Bool { viewer.canAssignShifts }

    /// Le specialità che si offrono: le sette categorie, più quelle che la persona ha già.
    static let specialtyCategories = ["mechanical", "electrical", "hydraulic", "pneumatic", "instrumentation",
                                      "cleaning", "general"]

    static func specialtyChoices(saved: [String]) -> [String] {
        specialtyCategories + saved.filter { !specialtyCategories.contains($0) }
    }

    // MARK: - Add user (§6.1)

    /// Le voci del livello per una persona nuova: Owner (spento al tetto), i ruoli attivi (alti, poi bassi),
    /// "No role" se non c'è un predefinito attivo, "Member" in un'azienda senza ruoli.
    static func addLevelOptions(page: AdminUsersPage, roles: [AdminRole], legacy: Bool) -> [AdminUserLevelOption] {
        var owner = AdminUserLevelOption(value: .owner, group: .owner, title: String(localized: "Owner"))
        if ownersFull(page) { owner.isDisabled = true; owner.hint = .ownerCap }
        if legacy {
            return [owner, AdminUserLevelOption(value: .none, group: .none, title: String(localized: "Member"))]
        }
        let enabled = roles.filter(\.enabled)
        var options = [owner] + enabled.filter { $0.set == .high }.map(option) + enabled.filter { $0.set == .low }.map(option)
        if demotionPreselect(roles) == nil {
            options.append(AdminUserLevelOption(value: .none, group: .none, title: String(localized: "No role")))
        }
        return options
    }

    /// La scelta di partenza: il ruolo predefinito se è attivo, altrimenti nessuno ("Member").
    static func addPreselect(roles: [AdminRole], legacy: Bool) -> AdminUserLevelValue {
        guard !legacy, let id = demotionPreselect(roles) else { return .none }
        return .role(id)
    }

    /// Il body di POST /v1/users: `role` è l'etichetta; `access_role_id` solo per un ruolo scelto.
    static func createBody(name: String, email: String, label: String, level: AdminUserLevelValue) -> AdminUserCreate {
        AdminUserCreate(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        fullName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        role: label, level: level == .owner ? "owner" : "member", accessRoleId: level.roleId)
    }

    /// La forma di un'email, controllata prima di mandare.
    static func isValidEmail(_ text: String) -> Bool {
        let email = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil
    }

    // MARK: - Il tetto (§6.4)

    enum CapState: Equatable {
        /// Si può aggiungere.
        case open
        /// "You've reached the user limit"
        case reached
        /// "You have more users than your plan includes": tutti tengono l'accesso.
        case over
    }

    /// Un tetto `hard` pieno ferma "Add user"; una lettura fallita (`nil`) lo lascia acceso: il server controlla.
    static func capState(_ info: AdminUserSeatsInfo?) -> CapState {
        guard let info, info.mode == "hard", let cap = info.userCap else { return .open }
        if info.users > cap { return .over }
        if info.taken >= cap { return .reached }
        return .open
    }

    /// "{used} of {total} seats used", o "{used} seats used" senza tetto: per chi non è titolare.
    static func seatsReadout(_ seats: AdminUsersPage.Seats) -> String {
        if let total = seats.total { return String(localized: "\(seats.used) of \(total) seats used") }
        return String(localized: "\(seats.used) seats used")
    }
}
