//
//  AdminUserDetailViewModel+Level.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il livello della persona (§5.2): le voci del selettore, cosa succede scegliendone una (AdminUsersRules.levelStep),
//  le conferme (diventare titolare, smettere di esserlo), il foglio del nuovo ruolo e l'invio. Il selezionato si
//  ricava sempre dalla riga: dopo un rifiuto il selettore torna al livello salvato rileggendo l'elenco.
//

import Foundation

extension AdminUserDetailViewModel {
    // MARK: - Il selettore

    /// Le voci del selettore; `nil`: il livello si mostra come testo.
    var levelOptions: [AdminUserLevelOption]? {
        guard let row, let page = owner.page, owner.hasLoaded else { return nil }
        // Senza i ruoli il selettore mostrerebbe solo Owner e No role: un tocco toglierebbe un ruolo mai mostrato.
        guard viewer.legacy || owner.hasLoadedRoles else { return nil }
        return AdminUsersRules.levelOptions(for: row, page: page, roles: owner.roles, viewer: viewer)
    }

    var currentLevel: AdminUserLevelValue? { row.map(AdminUsersRules.currentLevel) }

    /// Il livello come lo dice la riga del selettore (o il testo semplice).
    var levelText: String {
        guard let row else { return "" }
        if let current = currentLevel, let option = levelOptions?.first(where: { $0.value == current }) {
            return option.title
        }
        return AdminUsersRules.levelText(row, legacy: viewer.legacy)
    }

    /// Le sezioni della pagina: Owner, ruoli alti, ruoli bassi, No role. Titolo solo dove dice qualcosa.
    struct LevelGroup: Identifiable {
        let group: AdminUserLevelOption.Group
        let title: String?
        let options: [AdminUserLevelOption]
        var id: String { title ?? "\(group)" }
    }

    var levelGroups: [LevelGroup] {
        let options = levelOptions ?? []
        func take(_ group: AdminUserLevelOption.Group, _ title: String?) -> LevelGroup? {
            let items = options.filter { $0.group == group }
            return items.isEmpty ? nil : LevelGroup(group: group, title: title, options: items)
        }
        // "Member" in un'azienda senza ruoli sta sotto "Owner", nella stessa sezione.
        if viewer.legacy { return options.isEmpty ? [] : [LevelGroup(group: .owner, title: nil, options: options)] }
        return [take(.owner, nil), take(.high, String(localized: "High roles")),
                take(.low, String(localized: "Low roles")), take(.none, nil)].compactMap { $0 }
    }

    // MARK: - Scegliere

    /// Il tocco su una voce: niente, o scrive, o chiede conferma, o apre il foglio del nuovo ruolo.
    func chooseLevel(_ value: AdminUserLevelValue) {
        guard !isWorking, let row else { return }
        switch AdminUsersRules.levelStep(from: row, to: value, roles: owner.roles, viewer: viewer) {
        case .nothing:
            levelPageCloses += 1
        case .send(let change):
            Task { await sendLevel(change) }
        case .confirmPromotion(let losingRole):
            levelConfirmation = .promote(losingRole: losingRole)
        case .chooseDemotionRole(let preselect, let isSelf):
            demotionRoleId = preselect
            demotion = AdminUserDemotion(isSelf: isSelf)
        case .confirmLegacyDemotion:
            levelConfirmation = .legacyDemotion
        }
    }

    /// Il pulsante del foglio: su se stessi ("Step down") manda subito, per un altro apre la seconda conferma
    /// quando il foglio si è chiuso.
    func continueDemotion() {
        guard let draft = demotion else { return }
        let roleId = demotionRoleId
        demotion = nil
        if draft.isSelf {
            Task { await sendLevel(.member(roleId: roleId)) }
        } else {
            afterDemotion = .demote(roleId: roleId)
        }
    }

    /// Il foglio si è chiuso: se si era scelto "Continue", ora si apre la conferma.
    func demotionSheetDismissed() {
        guard let next = afterDemotion else { return }
        afterDemotion = nil
        levelConfirmation = next
    }

    func confirmLevel(_ item: AdminUserLevelConfirmation) {
        levelConfirmation = nil
        switch item {
        case .promote:
            Task { await sendLevel(.owner) }
        case .demote(let roleId):
            Task { await sendLevel(.member(roleId: roleId)) }
        case .legacyDemotion:
            Task { await sendLevel(.member(roleId: nil)) }
        }
    }

    /// PUT …/level; dopo, riga, ruoli e /v1/me si rileggono sia che sia andata sia che sia stata rifiutata.
    func sendLevel(_ change: AdminUserLevelChange) async {
        guard let api = owner.api, let row else { return }
        let name = row.displayName
        let ok = await write(rolesChanged: true) {
            let updated = try await api.setLevel(userId: userId, change)
            return levelToast(name: name, change: change, updated: updated)
        }
        if ok { levelPageCloses += 1 }
    }

    private func levelToast(name: String, change: AdminUserLevelChange, updated: AdminUserRow) -> String {
        switch change {
        case .owner:
            return String(localized: "\(name) is now an owner.")
        case .member(let roleId):
            guard let roleId else { return String(localized: "\(name) now has no role.") }
            let role = updated.role?.name ?? owner.roles.first { $0.id == roleId }?.name ?? ""
            return String(localized: "\(name) now has \(role).")
        }
    }

    // MARK: - Il foglio del nuovo ruolo

    /// Tutti i ruoli, gli alti prima; uno in pausa si legge "{name} (paused)".
    struct DemotionRole: Identifiable {
        let id: String
        let title: String
    }

    var demotionRoles: [DemotionRole] {
        (owner.roles.filter { $0.set == .high } + owner.roles.filter { $0.set == .low })
            .map { DemotionRole(id: $0.id, title: AdminUsersRules.roleTitle(name: $0.name, enabled: $0.enabled)) }
    }

    var demotionButtonTitle: String {
        demotion?.isSelf == true ? String(localized: "Step down") : String(localized: "Continue")
    }

    // MARK: - Testi

    func levelAlert(_ item: AdminUserLevelConfirmation) -> AdminUserAlertContent {
        let name = name
        switch item {
        case .promote(let losingRole):
            var message = String(localized: "\(name) will hold every section and can make or remove owners.")
            if let losingRole { message += " " + String(localized: "Their role, \(losingRole), is removed.") }
            return AdminUserAlertContent(title: String(localized: "Make \(name) an owner?"), message: message,
                                         confirmTitle: String(localized: "Make owner"))
        case .demote(let roleId):
            let roleName = roleId.flatMap { id in owner.roles.first { $0.id == id }?.name }
            let message = roleName.map { String(localized: "\(name) will hold only what \($0) gives.") }
                ?? String(localized: "\(name) will hold no section until a role is given.")
            return AdminUserAlertContent(title: String(localized: "Remove \(name) as an owner?"), message: message,
                                         confirmTitle: String(localized: "Remove as owner"), isDestructive: true)
        case .legacyDemotion:
            return AdminUserAlertContent(title: String(localized: "Remove \(name) as an owner?"),
                                         message: String(localized: "\(name) will no longer be an owner."),
                                         confirmTitle: String(localized: "Remove as owner"), isDestructive: true)
        }
    }
}
