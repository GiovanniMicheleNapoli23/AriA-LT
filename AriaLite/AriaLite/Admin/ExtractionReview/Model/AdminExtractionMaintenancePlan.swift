//
//  AdminExtractionMaintenancePlan.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un piano di manutenzione estratto da un documento (MaintenancePlanResponse): frequenza, attività e
//  ricambi. Lettura tollerante: serve solo il nome; senza `id` si vede ma non si modifica.
//

import Foundation

nonisolated struct AdminExtractionMaintenancePlan: Decodable, Sendable, Hashable {
    let serverId: String?
    let name: String
    /// Valore grezzo di MaintenanceFrequency (`daily`, `weekly`, `monthly`, `yearly`).
    let frequency: String?
    let frequencyHours: Double?
    let status: String?
    let assetTag: String?
    let plantId: String?
    let category: String?
    let zone: String?
    let description: String?
    let tasks: [String]
    let spareParts: [String]
    let estimatedDurationMin: Int?
    let confidence: Double?
    let createdAt: Date?
    let updatedAt: Date?

    init(from decoder: any Decoder) throws {
        let wire = try AdminExtractionWire(from: decoder)
        guard let name = wire.string("name") else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Plan without name"))
        }
        self.name = name
        serverId = wire.string("id")
        frequency = wire.string("frequency")
        frequencyHours = wire.double("frequencyHours")
        status = wire.string("status")
        assetTag = wire.string("assetTag")
        plantId = wire.string("plantId")
        category = wire.string("category")
        zone = wire.string("zone")
        description = wire.string("description")
        tasks = wire.strings("tasks")
        spareParts = wire.strings("spareParts")
        estimatedDurationMin = wire.int("estimatedDurationMin")
        confidence = wire.double("confidence")
        createdAt = wire.date("createdAt")
        updatedAt = wire.date("updatedAt")
    }
}

/// MaintenanceFrequency, con l'etichetta da mostrare. Un valore nuovo del backend si mostra com'è.
nonisolated enum AdminExtractionPlanFrequency: String, CaseIterable, Sendable {
    case daily, weekly, monthly, yearly

    var label: String {
        switch self {
        case .daily: String(localized: "Daily")
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        }
    }

    static func label(for raw: String) -> String {
        Self(rawValue: raw.lowercased())?.label ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
