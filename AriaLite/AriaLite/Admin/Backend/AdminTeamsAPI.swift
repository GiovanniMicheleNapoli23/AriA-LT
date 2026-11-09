//
//  AdminTeamsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Rotte delle squadre per un account della piattaforma (pagine /teams, /teams/{id} e /board della web): squadre,
//  membri, carico, ordini della squadra e spostamento di un ordine. Body in snake_case (`.snakeCased()`); carico e
//  ordini si leggono dal JSON così com'è, perché lo schema del server è libero.
//

import Foundation

nonisolated struct AdminTeamsAPI: Sendable {
    let api: AriaAPIClient

    private let teams = "v1/teams"

    // MARK: Squadre

    /// GET /v1/teams: tutte le squadre dell'azienda (il filtro per stabilimento è sul telefono). Una riga
    /// illeggibile si salta.
    func list() async throws -> [AdminTeam] {
        let endpoint: AriaEndpoint<AriaLossyArray<AdminTeam>> = AriaEndpoint.get(teams).snakeCased()
        return try await api.call(endpoint).items
    }

    func team(id: String) async throws -> AdminTeam {
        try await api.call(AriaEndpoint<AdminTeam>.get("\(teams)/\(id)").snakeCased())
    }

    func create(_ body: AdminTeamCreate) async throws -> AdminTeam {
        try await api.call(.post(teams, body: body).snakeCased())
    }

    func update(id: String, _ body: AdminTeamUpdate) async throws -> AdminTeam {
        try await api.call(.patch("\(teams)/\(id)", body: body).snakeCased())
    }

    /// DELETE /v1/teams/{id}: la risposta non serve.
    func delete(id: String) async throws {
        let _: AriaNoContent = try await api.call(AriaEndpoint<AriaNoContent>.delete("\(teams)/\(id)").snakeCased())
    }

    // MARK: Membri

    func addMember(teamId: String, _ body: AdminTeamMemberCreate) async throws -> AdminTeamMember {
        try await api.call(.post("\(teams)/\(teamId)/members", body: body).snakeCased())
    }

    func removeMember(teamId: String, memberId: String) async throws {
        let _: AriaNoContent = try await api.call(
            AriaEndpoint<AriaNoContent>.delete("\(teams)/\(teamId)/members/\(memberId)").snakeCased())
    }

    /// GET /v1/members: le persone fra cui scegliere chi aggiungere. Una riga illeggibile si salta.
    func people() async throws -> [AdminTeamPerson] {
        let endpoint: AriaEndpoint<AriaLossyArray<AdminTeamPerson>> = AriaEndpoint.get("v1/members").snakeCased()
        return try await api.call(endpoint).items
    }

    // MARK: Carico e ordini

    /// GET /v1/teams/{id}/workload. Senza `.snakeCased()`: le chiavi delle distribuzioni sono valori
    /// (`in_progress`) e restano come le scrive il server; `AdminTeamWorkload` legge le sue chiavi a mano.
    func workload(teamId: String) async throws -> AdminTeamWorkload {
        try await api.call(AriaEndpoint<AdminTeamWorkload>.get("\(teams)/\(teamId)/workload"))
    }

    /// Il carico di più squadre insieme; quelle che non rispondono mancano dal risultato.
    func workloads(teamIds: [String]) async -> [String: AdminTeamWorkload] {
        await withTaskGroup(of: (String, AdminTeamWorkload?).self) { group in
            for id in teamIds {
                group.addTask { (id, try? await workload(teamId: id)) }
            }
            var result: [String: AdminTeamWorkload] = [:]
            for await (id, workload) in group {
                if let workload { result[id] = workload }
            }
            return result
        }
    }

    /// GET /v1/teams/{id}/work-orders: JSON libero, righe senza id scartate.
    func workOrders(teamId: String) async throws -> [AdminTeamWorkOrder] {
        let json: AriaJSON = try await api.call(AriaEndpoint<AriaJSON>.get("\(teams)/\(teamId)/work-orders"))
        return AdminTeamWorkOrder.rows(from: json)
    }

    /// PATCH /v1/work-orders/{id}: sposta un ordine di stato o di squadra. La risposta non serve.
    func updateWorkOrder(id: String, _ body: AdminTeamWorkOrderPatch) async throws {
        let _: AriaNoContent = try await api.call(.patch("v1/work-orders/\(id)", body: body).snakeCased())
    }
}
