//
//  AdminAsset.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un asset dello stabilimento (AssetResponse del backend). Lettura tollerante: servono solo
//  il tag e, per modificarlo, l'id; tutto il resto può mancare o avere valori nuovi.
//

import Foundation

nonisolated struct AdminAsset: Decodable, Sendable, Identifiable, Hashable {
    /// L'id del server: senza, l'asset si vede ma non si modifica (PATCH /v1/assets/{asset_id}).
    let serverId: String?
    let tag: String
    let name: String
    /// Valore grezzo (`motor`, `pump`…): un tipo nuovo del backend resta com'è (vedi AdminAssetType).
    let assetType: String?
    /// Valore grezzo (`approved`, `draft`…), vedi AdminAssetStatus.
    let status: String?
    let zone: String?
    let powerKw: Double?
    let description: String?
    let plantId: String?
    let manufacturer: String?
    let model: String?
    let serialNumber: String?
    let driveTag: String?
    let driveType: String?
    let notes: String?
    /// Quanto è sicura l'estrazione automatica (0…1) per gli asset proposti dall'AI.
    let confidence: Double?
    let createdAt: Date?
    let updatedAt: Date?

    var id: String { serverId ?? tag }
    var type: AdminAssetType? { assetType.flatMap(AdminAssetType.init(rawValue:)) }
    var knownStatus: AdminAssetStatus? { status.flatMap(AdminAssetStatus.init(rawValue:)) }

    var typeLabel: String? { assetType.map(AdminAssetType.label(for:)) }
    var statusLabel: String? { status.map(AdminAssetStatus.label(for:)) }

    /// Le chiavi arrivano già in camelCase (`.snakeCased()` sull'endpoint).
    private enum CodingKeys: String, CodingKey {
        case id, tag, name, assetType, status, zone, powerKw, description, plantId, manufacturer, model
        case serialNumber, driveTag, driveType, notes, confidence, createdAt, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            guard let value = try? c.decodeIfPresent(AriaFlexibleID.self, forKey: key)?.value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        func number(_ key: CodingKeys) -> Double? {
            if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
            return text(key).flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
        }
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }

        guard let tag = text(.tag) else {
            throw DecodingError.keyNotFound(CodingKeys.tag, .init(codingPath: c.codingPath, debugDescription: "Asset senza tag"))
        }
        self.tag = tag
        serverId = text(.id)
        name = text(.name) ?? tag
        assetType = text(.assetType)
        status = text(.status)
        zone = text(.zone)
        powerKw = number(.powerKw)
        description = text(.description)
        plantId = text(.plantId)
        manufacturer = text(.manufacturer)
        model = text(.model)
        serialNumber = text(.serialNumber)
        driveTag = text(.driveTag)
        driveType = text(.driveType)
        notes = text(.notes)
        confidence = number(.confidence)
        createdAt = date(.createdAt)
        updatedAt = date(.updatedAt)
    }

    /// "Motore · Zona A": la seconda riga della scheda nella lista.
    var summaryLine: String { [typeLabel, zone].compactMap { $0 }.joined(separator: " · ") }

    /// Il testo in cui cerca la barra di ricerca della lista: tag, nome, costruttore e modello.
    var searchableFields: [String] { [tag, name, manufacturer, model].compactMap { $0 } }
}
