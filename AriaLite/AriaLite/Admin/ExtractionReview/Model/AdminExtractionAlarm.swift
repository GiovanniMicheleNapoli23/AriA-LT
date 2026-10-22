//
//  AdminExtractionAlarm.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un allarme estratto da un documento (AlarmResponse): codice, descrizione, cause tipiche e passi di
//  risoluzione. Lettura tollerante: serve solo il codice; senza `id` si vede ma non si modifica.
//

import Foundation

nonisolated struct AdminExtractionAlarm: Decodable, Sendable, Hashable {
    let serverId: String?
    let code: String
    let description: String?
    /// Valore grezzo di EntityStatus (`draft`, `staged`…).
    let status: String?
    let assetTag: String?
    let category: String?
    let zone: String?
    let hmiPage: String?
    let typicalCauses: [String]
    let resolutionSteps: [String]
    let confidence: Double?
    let createdAt: Date?
    let updatedAt: Date?

    init(from decoder: any Decoder) throws {
        let wire = try AdminExtractionWire(from: decoder)
        guard let code = wire.string("code") else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Alarm without code"))
        }
        self.code = code
        serverId = wire.string("id")
        description = wire.string("description")
        status = wire.string("status")
        assetTag = wire.string("assetTag")
        category = wire.string("category")
        zone = wire.string("zone")
        hmiPage = wire.string("hmiPage")
        typicalCauses = wire.strings("typicalCauses")
        resolutionSteps = wire.strings("resolutionSteps")
        confidence = wire.double("confidence")
        createdAt = wire.date("createdAt")
        updatedAt = wire.date("updatedAt")
    }
}
