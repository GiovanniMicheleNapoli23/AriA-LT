//
//  AdminRolesViewModel+Writes.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Le scritture di Roles & Rights. Una per ruolo alla volta: mentre va (e finché non arriva la rilettura che la
//  segue) i comandi del ruolo sono spenti, perché un secondo tocco porterebbe la `version` vecchia. Lo schermo
//  mostra subito lo stato che la scrittura lascerà; se il server rifiuta torna com'era e si rilegge l'elenco.
//

import Foundation

extension AdminRolesViewModel {
    enum Outcome: Equatable {
        case done
        /// 409 `role_name_taken`: il messaggio va sotto il campo del nome, non in un avviso.
        case nameTaken
        /// 409 `role_has_members` dalla DELETE senza body: qualcuno ha preso il ruolo nel frattempo.
        case hasMembers
        case failed(String?)
    }

    // MARK: - Interruttori

    func setEnabled(_ role: AdminRole, _ enabled: Bool) async {
        await change(role, apply: { $0.enabled = enabled }) { api, current in
            try await api.setEnabled(id: current.id, AdminRoleEnabled(enabled: enabled, version: current.version))
        }
    }

    /// Accesa: la sezione senza azioni. Spenta: via la sezione e tutte le sue azioni.
    func setSection(_ section: String, on: Bool, in role: AdminRole) async {
        await change(role, apply: { $0.grants[section] = on ? [] : nil }) { api, current in
            try await api.setGrant(id: current.id, section: section,
                                   AdminRoleGrant(enabled: on, actions: [], version: current.version))
        }
    }

    /// Un chip manda tutta la lista nuova della sezione: quella di ora, con l'azione aggiunta o tolta.
    func toggleAction(_ action: String, in section: String, of role: AdminRole) async {
        guard let current = role.grants[section] else { return }
        let order = catalog.first { $0.section == section }?.actions ?? []
        let wanted = current.contains(action) ? Set(current).subtracting([action]) : Set(current).union([action])
        let list = order.filter(wanted.contains) + wanted.subtracting(order).sorted()
        await change(role, apply: { $0.grants[section] = list }) { api, current in
            try await api.setGrant(id: current.id, section: section,
                                   AdminRoleGrant(enabled: true, actions: list, version: current.version))
        }
    }

    /// Il cuore delle modifiche a un ruolo: lo stato nuovo subito, la chiamata con la versione dell'ultima copia
    /// letta, la risposta al suo posto e poi la rilettura. Spento finché la rilettura non è arrivata.
    @discardableResult
    private func change(_ role: AdminRole, apply: (inout AdminRole) -> Void,
                        send: (AdminRolesAPI, AdminRole) async throws -> AdminRole,
                        refusal: (AriaAccessRefusal) -> Bool = { _ in false }) async -> Outcome {
        guard mayChange(role), let api = rolesAPI, let index = roles.firstIndex(where: { $0.id == role.id }),
              !busyRoleIds.contains(role.id) else { return .failed(nil) }
        let before = roles[index]
        busyRoleIds.insert(role.id)
        defer { busyRoleIds.remove(role.id) }
        apply(&roles[index])
        do {
            let saved = try await send(api, before)
            replace(saved)
            await reloadRoles()
            return .done
        } catch {
            if let index = roles.firstIndex(where: { $0.id == before.id }) { roles[index] = before }
            if let code = AdminRolesFailure.refusal(error), refusal(code) {
                await reloadRoles()
                return code == .roleNameTaken ? .nameTaken : .failed(nil)
            }
            return .failed(await refuse(error, about: .role))
        }
    }

    /// La risposta di una scrittura prende il posto della copia nell'elenco: la prossima scrittura ne usa la versione.
    private func replace(_ saved: AdminRole) {
        if let index = roles.firstIndex(where: { $0.id == saved.id }) {
            roles[index] = saved
        } else {
            roles.append(saved)
        }
    }

    /// Dopo un rifiuto: l'avviso, la rilettura dell'elenco prima del prossimo tocco e, se il proprio ruolo potrebbe
    /// essere cambiato (`escalation_denied`), anche quella di GET /v1/me. Restituisce il messaggio mostrato.
    @discardableResult
    func refuse(_ error: any Error, about subject: AdminRolesFailure.Subject, showing: Bool = true) async -> String? {
        guard let message = AdminRolesFailure.message(for: error, about: subject, backend: backend) else { return nil }
        if showing { show(message, isError: true) }
        if AdminRolesFailure.refusal(error) == .escalationDenied { await backend.refreshMembership() }
        await reloadRoles()
        return message
    }

    var rolesAPI: AdminRolesAPI? {
        backend.activeCompanyId.map { AdminRolesAPI(api: backend.api, companyId: $0) }
    }

    // MARK: - Nuovo ruolo

    /// "Nuovo ruolo" (o "Nuovo ruolo base" per un ruolo alto): si crea senza sezioni e si apre.
    func startCreating() {
        guard viewer != nil else { return }
        createForm = AdminRoleCreateViewModel(owner: self)
    }

    func create(name: String, set: AdminRoleSet) async -> Outcome {
        guard let api = rolesAPI else { return .failed(nil) }
        // Un ruolo alto crea solo ruoli base.
        let level = isAdmin ? set : .low
        do {
            let created = try await api.create(AdminRoleCreate(name: name, set: level, grants: [:]))
            replace(created)
            show(String(localized: "\(created.name) created"))
            path = [.role(created.id)]
            await reloadRoles()
            return .done
        } catch {
            if AdminRolesFailure.refusal(error) == .roleNameTaken { return .nameTaken }
            return .failed(await refuse(error, about: .role, showing: false))
        }
    }

    // MARK: - Rinomina

    func rename(_ role: AdminRole, to name: String) async -> Outcome {
        let outcome = await change(role, apply: { $0.name = name }, send: { api, current in
            try await api.rename(id: current.id, AdminRoleRename(version: current.version, name: name))
        }, refusal: { $0 == .roleNameTaken })
        if outcome == .done { show(String(localized: "Renamed to \(name)")) }
        return outcome
    }

    // MARK: - Ruolo predefinito

    /// Solo owner e admin. Lo stesso ruolo di adesso non cambia niente: non si chiama il server.
    func setDefault(_ roleId: String) async {
        guard isAdmin, !isSettingDefault, roleId != currentDefault?.id, let api = rolesAPI,
              let role = role(id: roleId) else { return }
        isSettingDefault = true
        defer { isSettingDefault = false }
        do {
            try await api.setDefault(roleId: roleId)
            for index in roles.indices { roles[index].isDefault = roles[index].id == roleId }
            show(String(localized: "\(role.name) is the default role now"))
            await reloadRoles()
        } catch {
            if AdminRolesFailure.refusal(error) == .roleNotAssignable {
                show(String(localized: "Only an enabled Low role can be the default."), isError: true)
                await reloadRoles()
            } else {
                await refuse(error, about: .role)
            }
        }
    }

    // MARK: - Eliminazione

    func askDelete(_ role: AdminRole) {
        guard mayDelete(role) else { return }
        deleteForm = AdminRoleDeleteViewModel(role: role, owner: self)
    }

    /// I ruoli a cui spostare chi ha `role`: per owner e admin ogni ruolo attivo, per un ruolo alto i suoi ruoli base
    /// attivi; mai quello che si elimina. "Nessun ruolo" lo aggiunge la schermata.
    func moveTargets(deleting role: AdminRole) -> [AdminRole] {
        roles.filter { other in
            guard other.id != role.id, other.enabled else { return false }
            switch viewer {
            case .admin?: return true
            case .high(let roleId, _)?: return other.set == .low && other.ownerRoleId == roleId
            case nil: return false
            }
        }
    }

    func delete(_ role: AdminRole, move: AdminRoleDeleteMove?) async -> Outcome {
        guard mayDelete(role), let api = rolesAPI, !busyRoleIds.contains(role.id) else { return .failed(nil) }
        busyRoleIds.insert(role.id)
        defer { busyRoleIds.remove(role.id) }
        do {
            try await api.delete(id: role.id, move: move)
            roles.removeAll { $0.id == role.id }
            holders[role.id] = nil
            show(String(localized: "\(role.name) deleted"))
            path = []
            await reloadEverything()
            return .done
        } catch {
            if AdminRolesFailure.refusal(error) == .roleHasMembers {
                await reloadRoles()
                return .hasMembers
            }
            return .failed(await refuse(error, about: .role, showing: false))
        }
    }

    // MARK: - Persone

    func loadHolders(of roleId: String) async {
        guard let api = rolesAPI else { return }
        if holders[roleId] == nil || holders[roleId] == .failed { holders[roleId] = .loading }
        do {
            holders[roleId] = .loaded(try await api.holders(roleId: roleId))
        } catch {
            guard AdminRolesFailure.message(for: error, about: .role, backend: backend) != nil else { return }
            // Una rilettura fallita lascia l'elenco che c'era.
            if case .loaded? = holders[roleId] { return }
            holders[roleId] = .failed
        }
    }

    func loadCandidates() async {
        guard let api = rolesAPI else { return }
        if candidates == nil || candidates == .failed { candidates = .loading }
        do {
            candidates = .loaded(try await api.assignableMembers())
        } catch {
            guard AdminRolesFailure.message(for: error, about: .person, backend: backend) != nil else { return }
            if case .loaded? = candidates { return }
            candidates = .failed
        }
    }

    func startAddingPeople(to role: AdminRole) {
        guard mayChange(role) else { return }
        candidates = nil
        addPeople = AdminRoleAddPeopleViewModel(roleId: role.id, owner: self)
    }

    /// Dà `role` a una persona (o glielo toglie con `role` nil, dal ruolo `from`).
    func assign(userId: String, name: String?, to role: AdminRole?, from: AdminRole? = nil) async {
        guard let target = role ?? from, mayChange(target), let api = rolesAPI, !busyPeople.contains(userId) else { return }
        busyPeople.insert(userId)
        defer { busyPeople.remove(userId) }
        let shownName = name.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "Unnamed person")
        do {
            try await api.assign(userId: userId, roleId: role?.id)
            if let role {
                show(String(localized: "\(shownName) now holds \(role.name)"))
            } else {
                show(String(localized: "\(shownName) has no role now"))
            }
            await reloadEverything()
        } catch {
            await refuse(error, about: .person)
            await reloadPeople()
        }
    }

    /// Dopo un'eliminazione o un ruolo dato o tolto: ruoli (i conteggi), chi li ha e i candidati.
    func reloadEverything() async {
        await reloadRoles()
        await reloadPeople()
    }

    private func reloadPeople() async {
        for roleId in holders.keys { await loadHolders(of: roleId) }
        if candidates != nil { await loadCandidates() }
    }
}
