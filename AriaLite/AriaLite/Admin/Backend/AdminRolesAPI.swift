//
//  AdminRolesAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  Rotte di Roles & Rights (pagina /roles della web), sotto /v1/companies/{companyId}: l'azienda è nel percorso.
//  Body e risposte in camelCase (niente `.snakeCased()`). Ogni modifica a un ruolo porta la `version` letta per
//  ultima: una vecchia è rifiutata con 409 `role_changed`.
//

import Foundation

nonisolated struct AdminRolesAPI: Sendable {
    let api: AriaAPIClient
    let companyId: String

    private var access: String { "v1/companies/\(companyId)/access" }
    private func role(_ id: String) -> String { "\(access)/roles/\(id)" }

    // MARK: Letture

    func catalog() async throws -> [AdminRoleCatalogSection] {
        try await api.call(AriaEndpoint<AdminRoleCatalog>.get("\(access)/catalog")).sections
    }

    /// I ruoli che chi guarda può vedere: prima gli alti, poi per nome.
    func roles() async throws -> [AdminRole] {
        try await api.call(AriaEndpoint<AdminRoleList>.get("\(access)/roles")).roles
    }

    func holders(roleId: String) async throws -> [AdminRoleHolder] {
        try await api.call(AriaEndpoint<AdminRoleMembersList<AdminRoleHolder>>.get("\(role(roleId))/members")).members
    }

    /// Chi guarda può dare un ruolo a queste persone: tutta l'azienda, si chiede solo per "Aggiungi persone".
    func assignableMembers() async throws -> [AdminRoleCandidate] {
        try await api.call(AriaEndpoint<AdminRoleMembersList<AdminRoleCandidate>>.get("\(access)/assignable-members")).members
    }

    // MARK: Scritture

    func create(_ body: AdminRoleCreate) async throws -> AdminRole {
        try await api.call(.post("\(access)/roles", body: body))
    }

    func rename(id: String, _ body: AdminRoleRename) async throws -> AdminRole {
        try await api.call(.patch(role(id), body: body))
    }

    func setEnabled(id: String, _ body: AdminRoleEnabled) async throws -> AdminRole {
        try await api.call(.put("\(role(id))/enabled", body: body))
    }

    func setGrant(id: String, section: String, _ body: AdminRoleGrant) async throws -> AdminRole {
        try await api.call(.put("\(role(id))/grants/\(section)", body: body))
    }

    /// DELETE: senza body si elimina solo se nessuno ha il ruolo (altrimenti 409 `role_has_members`); con `move`
    /// chi lo ha passa a quel ruolo, o a nessuno (`moveTo: null`).
    func delete(id: String, move: AdminRoleDeleteMove?) async throws {
        var endpoint = AriaEndpoint<AriaNoContent>.delete(role(id))
        // Solo un valore vero: un Optional passato com'è finirebbe codificato come body `null`.
        if let move { endpoint.body = move }
        let _: AriaNoContent = try await api.call(endpoint)
    }

    func setDefault(roleId: String) async throws {
        let _: AriaNoContent = try await api.call(.put("\(access)/default-role", body: AdminRoleDefault(roleId: roleId)))
    }

    /// Dà, cambia o toglie (`roleId` nil) il ruolo di una persona.
    func assign(userId: String, roleId: String?) async throws {
        let path = "v1/companies/\(companyId)/members/\(userId)/access-role"
        let _: AriaNoContent = try await api.call(.put(path, body: AdminRoleAssignment(roleId: roleId)))
    }
}
