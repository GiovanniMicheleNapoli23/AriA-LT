//
//  AdminMembersAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte dei membri (pagina /members della web): elenco e dettaglio, turni, assegnazioni, team ad hoc
//  e nuovo utente.
//  Body e risposte in snake_case (`.snakeCased()`), i modelli restano in camelCase.
//

import Foundation

nonisolated struct AdminMembersAPI: Sendable {
    let api: AriaAPIClient

    /// GET /v1/members: array di righe; una riga illeggibile si salta, le altre restano.
    /// Ricerca e filtri si fanno sul telefono, quindi non si mandano `q` né `on_date`. Senza i due parametri il
    /// server nasconde i sospesi e chi non lavora sul campo: qui si chiede tutta l'azienda.
    func list() async throws -> [AdminMember] {
        let endpoint: AriaEndpoint<AriaLossyArray<AdminMember>> =
            AriaEndpoint<AriaLossyArray<AdminMember>>.get(
                "v1/members", query: ["field_only": "false", "active_only": "false"]).snakeCased()
        return try await api.call(endpoint).items
    }

    /// GET /v1/members/{user_id}
    func member(id: String) async throws -> AdminMember {
        try await api.call(AriaEndpoint<AdminMember>.get("v1/members/\(id)").snakeCased())
    }

    /// GET /v1/members/{user_id}/shifts nell'intervallo di giorni (`YYYY-MM-DD`).
    func shifts(userId: String, from: String, to: String) async throws -> [AdminMemberShift] {
        let query = [URLQueryItem(name: "from_date", value: from), URLQueryItem(name: "to_date", value: to)]
        let endpoint: AriaEndpoint<AriaLossyArray<AdminMemberShift>> =
            AriaEndpoint(method: "GET", path: "v1/members/\(userId)/shifts", query: query).snakeCased()
        return try await api.call(endpoint).items
    }

    /// POST /v1/member-assignments: il 201 ha uno schema vuoto, la risposta non si legge.
    func assign(_ body: AdminMemberAssignmentCreate) async throws {
        let endpoint = AriaEndpoint<AriaNoContent>.post("v1/member-assignments", body: body).snakeCased()
        let _: AriaNoContent = try await api.call(endpoint)
    }

    /// DELETE /v1/member-assignments/{assignment_id}
    func removeAssignment(id: String) async throws {
        let endpoint = AriaEndpoint<AriaNoContent>.delete("v1/member-assignments/\(id)").snakeCased()
        let _: AriaNoContent = try await api.call(endpoint)
    }

    /// GET /v1/teams: solo quel che serve a scegliere il team di un turno.
    func teams() async throws -> [AdminMemberTeamOption] {
        let endpoint: AriaEndpoint<AriaLossyArray<AdminMemberTeamOption>> =
            AriaEndpoint<AriaLossyArray<AdminMemberTeamOption>>.get("v1/teams").snakeCased()
        return try await api.call(endpoint).items
    }

    /// POST /v1/users: nuovo utente dell'azienda (201 con `id`). Si rilegge l'elenco dei membri dopo.
    @discardableResult
    func createUser(_ body: AdminMemberUserCreate) async throws -> AdminMemberCreated {
        try await api.call(AriaEndpoint<AdminMemberCreated>.post("v1/users", body: body).snakeCased())
    }

    /// PATCH /v1/members/{user_id}: nome, qualifica, specialità, lavoro sul campo, stato in azienda.
    func update(userId: String, _ body: AdminMemberUpdate) async throws -> AdminMember {
        try await api.call(AriaEndpoint<AdminMember>.patch("v1/members/\(userId)", body: body).snakeCased())
    }

    /// DELETE /v1/companies/{company_id}/members/{user_id}: la persona esce dall'azienda (204).
    func removeFromCompany(companyId: String, userId: String) async throws {
        let _: AriaNoContent = try await api.call(
            AriaEndpoint<AriaNoContent>.delete("v1/companies/\(companyId)/members/\(userId)"))
    }
}
