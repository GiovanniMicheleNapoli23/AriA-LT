//
//  AdminKnowledgeGraphWorkOrder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ordine di lavoro visto dal grafo (WorkOrderResponse ridotto): servono i campi che lo collegano
//  ad asset, allarme, piano e stabilimento, più quelli da mostrare nella riga.
//

import Foundation

nonisolated struct AdminKnowledgeGraphWorkOrder: Decodable, Sendable, Hashable {
    let serverId: String?
    let title: String
    let status: String?
    let priority: String?
    let type: String?
    let category: String?
    let description: String?
    let assetTag: String?
    let alarmCode: String?
    let maintenancePlanId: String?
    let plantId: String?
    let zone: String?
    let dueDate: Date?
    let completedAt: Date?
    let createdAt: Date?

    init(from decoder: any Decoder) throws {
        let wire = try AdminKnowledgeGraphWire(decoder)
        serverId = wire.text("id")
        guard let title = wire.text("title") ?? serverId else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Ordine senza titolo"))
        }
        self.title = title
        status = wire.text("status")
        priority = wire.text("priority")
        type = wire.text("type")
        category = wire.text("category")
        description = wire.text("description")
        assetTag = wire.text("assetTag")
        alarmCode = wire.text("alarmCode")
        maintenancePlanId = wire.text("maintenancePlanId")
        plantId = wire.text("plantId")
        zone = wire.text("zone")
        dueDate = wire.date("dueDate")
        completedAt = wire.date("completedAt") ?? wire.date("completedDate")
        createdAt = wire.date("createdAt")
    }
}
