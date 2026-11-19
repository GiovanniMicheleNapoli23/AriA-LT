//
//  AdminMembersAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte dei membri con l'azienda nell'header `Company-Id` (la scheda della persona in Users): dettaglio, turni,
//  assegnazioni e team.
//  Body e risposte in snake_case (`.snakeCased()`), i modelli restano in camelCase.
//

import Foundation

nonisolated struct AdminMembersAPI: Sendable {
    let api: AriaAPIClient

    /// GET /v1/members/{user_id}
    func member(id: String) async throws -> AdminMember {
        try await api.call(AriaEndpoint<AdminMember>.get("v1/members/\(id)").snakeCased())
    }

    /// GET /v1/members/{user_id}/shifts: tutte le assegnazioni, le più recenti prima; le date (`YYYY-MM-DD`) restringono.
    func shifts(userId: String, from: String? = nil, to: String? = nil) async throws -> [AdminMemberShift] {
        let query = [("from_date", from), ("to_date", to)].compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
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
}
