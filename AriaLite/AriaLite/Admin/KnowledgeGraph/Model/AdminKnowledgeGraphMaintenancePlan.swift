//
//  AdminKnowledgeGraphMaintenancePlan.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un piano di manutenzione (MaintenancePlanResponse): frequenza, asset principale e collegati,
//  attività e ricambi (testi liberi: codici o nomi, si collegano ai ricambi nel view model).
//

import Foundation

nonisolated struct AdminKnowledgeGraphMaintenancePlan: Decodable, Sendable, Hashable {
    let serverId: String?
    let name: String
    let frequency: String?
    let frequencyHours: Double?
    let status: String?
    let assetTag: String?
    let relatedAssetTags: [String]
    let plantId: String?
    let category: String?
    let zone: String?
    let description: String?
    let tasks: [String]
    let spareParts: [String]
    let estimatedDurationMin: Int?
    let lastDoneAt: Date?
    let nextDueAt: Date?

    init(from decoder: any Decoder) throws {
        let wire = try AdminKnowledgeGraphWire(decoder)
        guard let name = wire.text("name") else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Piano senza nome"))
        }
        self.name = name
        serverId = wire.text("id")
        frequency = wire.text("frequency")
        frequencyHours = wire.number("frequencyHours")
        status = wire.text("status")
        assetTag = wire.text("assetTag")
        relatedAssetTags = wire.texts("relatedAssetTags")
        plantId = wire.text("plantId")
        category = wire.text("category")
        zone = wire.text("zone")
        description = wire.text("description")
        tasks = wire.texts("tasks")
        spareParts = wire.texts("spareParts")
        estimatedDurationMin = wire.integer("estimatedDurationMin")
        lastDoneAt = wire.date("lastDoneAt")
        nextDueAt = wire.date("nextDueAt")
    }

    /// L'asset principale e quelli collegati, senza doppioni.
    var allAssetTags: [String] {
        var seen = Set<String>()
        return ([assetTag].compactMap { $0 } + relatedAssetTags).filter { seen.insert($0.lowercased()).inserted }
    }
}
