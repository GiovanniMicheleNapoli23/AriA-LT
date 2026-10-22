//
//  AdminAlarm.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un allarme come lo manda il backend (AlarmResponse). Lettura tollerante: servono solo `id` e `code`
//  (nell'OpenAPI `id` è facoltativo, ma senza non si apre il dettaglio); il resto, se illeggibile, vale
//  come assente. Le chiavi arrivano già in camelCase dalla chiamata `.snakeCased()`.
//

import Foundation

nonisolated struct AdminAlarm: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var code: String
    var description: String
    /// Il valore di EntityStatus come l'ha scritto il server (vedi `status`).
    var statusKey: String
    var assetTag: String?
    var category: String?
    var zone: String?
    var hmiPage: String?
    var typicalCauses: [String]
    var resolutionSteps: [String]
    var confidence: Double?
    var createdAt: Date?
    var updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, code, description, status, assetTag, category, zone, hmiPage
        case typicalCauses, resolutionSteps, confidence, createdAt, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        func text(_ key: CodingKeys) -> String? { json(key)?.nonEmptyString }
        func lines(_ key: CodingKeys) -> [String] { json(key)?.arrayValue.compactMap(\.nonEmptyString) ?? [] }
        guard let id = text(.id), let code = text(.code) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Alarm without id or code"))
        }
        self.id = id
        self.code = code
        description = text(.description) ?? ""
        statusKey = text(.status)?.lowercased() ?? AdminAlarmStatus.draft.rawValue
        assetTag = text(.assetTag)
        category = text(.category)
        zone = text(.zone)
        hmiPage = text(.hmiPage)
        typicalCauses = lines(.typicalCauses)
        resolutionSteps = lines(.resolutionSteps)
        confidence = json(.confidence)?.doubleValue.flatMap { $0.isFinite ? $0 : nil }
        createdAt = text(.createdAt).flatMap(AriaWireDate.parse)
        updatedAt = text(.updatedAt).flatMap(AriaWireDate.parse)
    }

    var status: AdminAlarmStatus? { AdminAlarmStatus(rawValue: statusKey) }

    /// Lo stato da mostrare: quello noto, o il testo del server se non lo conosciamo.
    var statusLabel: String { status?.label ?? statusKey.capitalized }

    /// Fiducia dell'estrazione come percentuale (0…100), se c'è. Il server la manda in 0…1 o in 0…100.
    var confidencePercent: Int? {
        guard let confidence else { return nil }
        let value = confidence <= 1 ? confidence * 100 : confidence
        return Int(min(max(value, 0), 100).rounded())
    }

    /// Metadati in una riga per l'elenco: zona e categoria.
    var placeSummary: String? {
        let parts = [zone, category].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
