//
//  AdminWorkOrdersAPI+Reassign.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  PATCH /v1/work-orders/{id} con la sola squadra: serve al piano di riassegnazione della chat.
//  La risposta non si legge, quindi un ordine che il client non sa decodificare non conta come fallito.
//

import Foundation

extension AdminWorkOrdersAPI {
    /// Assegna l'ordine a una squadra: body `{"assigned_to_team_id": "<id>"}`.
    func reassign(_ id: String, toTeam teamId: String) async throws {
        let body = AdminWorkOrderUpdate(assignedToTeamId: teamId)
        let _: AriaNoContent = try await api.call(.patch("\(root)/\(id)", body: body).snakeCased())
    }
}
