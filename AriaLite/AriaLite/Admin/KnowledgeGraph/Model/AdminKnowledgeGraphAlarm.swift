//
//  AdminKnowledgeGraphAlarm.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un allarme della base di conoscenza (AlarmResponse): codice, descrizione, asset a cui si riferisce,
//  cause tipiche e passi di risoluzione. Serve solo il codice; tutto il resto può mancare.
//

import Foundation

nonisolated struct AdminKnowledgeGraphAlarm: Decodable, Sendable, Hashable {
    let serverId: String?
    let code: String
    let description: String?
    let status: String?
    let assetTag: String?
    let category: String?
    let zone: String?
    let hmiPage: String?
    let typicalCauses: [String]
    let resolutionSteps: [String]
    let confidence: Double?
    let updatedAt: Date?

    init(from decoder: any Decoder) throws {
        let wire = try AdminKnowledgeGraphWire(decoder)
        guard let code = wire.text("code") else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Allarme senza codice"))
        }
        self.code = code
        serverId = wire.text("id")
        description = wire.text("description")
        status = wire.text("status")
        assetTag = wire.text("assetTag")
        category = wire.text("category")
        zone = wire.text("zone")
        hmiPage = wire.text("hmiPage")
        typicalCauses = wire.texts("typicalCauses")
        resolutionSteps = wire.texts("resolutionSteps")
        confidence = wire.number("confidence")
        updatedAt = wire.date("updatedAt")
    }
}
