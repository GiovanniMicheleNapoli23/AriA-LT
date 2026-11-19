//
//  AdminAlarmEventsAPI.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Rotte degli eventi di allarme, quelli che l'impianto ha alzato (OPC-UA…): elenco, conteggio dei non letti,
//  segna come letto (uno o tutti). Il `plant_id` si manda solo se c'è un impianto attivo.
//

import Foundation

nonisolated struct AdminAlarmEventsAPI: Sendable {
    let api: AriaAPIClient

    private let events = "v1/alarm-events"

    /// GET /v1/alarm-events?status=&limit=200&plant_id=: una riga illeggibile si salta, le altre restano.
    func list(filter: AdminAlarmEventFilter, plantId: String?) async throws -> [AdminAlarmEvent] {
        var endpoint: AriaEndpoint<AriaLossyArray<AdminAlarmEvent>> = .get(events).snakeCased()
        endpoint.query = [URLQueryItem(name: "status", value: filter.rawValue), URLQueryItem(name: "limit", value: "200")]
            + plantItems(plantId)
        return try await api.call(endpoint).items
    }

    /// GET /v1/alarm-events/unread-count?plant_id=: `{"count": n}`.
    func unreadCount(plantId: String?) async throws -> Int {
        var endpoint: AriaEndpoint<AdminAlarmEventCount> = .get("\(events)/unread-count").snakeCased()
        endpoint.query = plantItems(plantId)
        return try await api.call(endpoint).count
    }

    /// POST /v1/alarm-events/{id}/read: la risposta (`{"status":"ok","id":…}`) non serve.
    func markRead(id: String) async throws {
        let _: AriaNoContent = try await api.call(AriaEndpoint<AriaNoContent>.post("\(events)/\(id)/read").snakeCased())
    }

    /// POST /v1/alarm-events/mark-all-read?plant_id=: la risposta (`{"updated": n}`) non serve.
    func markAllRead(plantId: String?) async throws {
        var endpoint: AriaEndpoint<AriaNoContent> = .post("\(events)/mark-all-read").snakeCased()
        endpoint.query = plantItems(plantId)
        let _: AriaNoContent = try await api.call(endpoint)
    }

    private func plantItems(_ plantId: String?) -> [URLQueryItem] {
        plantId.map { [URLQueryItem(name: "plant_id", value: $0)] } ?? []
    }
}
