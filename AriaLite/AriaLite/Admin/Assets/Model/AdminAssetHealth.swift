//
//  AdminAssetHealth.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  Il punteggio di salute di un asset (AssetHealthScoreResponse): punteggio 0-100, voto, fattori di rischio,
//  raccomandazioni e segnali. Lettura tollerante: servono solo il tag e il punteggio, il resto può mancare.
//

import Foundation

nonisolated struct AdminAssetHealth: Decodable, Sendable, Equatable {
    let assetTag: String
    /// 0...100.
    let score: Double
    /// "A"..."F", come lo manda il server.
    let grade: String
    let isCritical: Bool
    let signals: [AdminAssetHealthSignal]
    let riskFactors: [String]
    let recommendations: [String]
    let windowDays: Int
    let computedAt: Date?

    /// Le chiavi arrivano già in camelCase (`.snakeCased()` sull'endpoint).
    private enum CodingKeys: String, CodingKey {
        case assetTag, score, grade, isCritical, signals, riskFactors, recommendations, windowDays, computedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        assetTag = (try? c.decodeIfPresent(String.self, forKey: .assetTag)) ?? ""
        score = try c.decode(Double.self, forKey: .score)
        grade = (try? c.decodeIfPresent(String.self, forKey: .grade)) ?? ""
        isCritical = (try? c.decodeIfPresent(Bool.self, forKey: .isCritical)) ?? false
        signals = (try? c.decodeIfPresent(AriaLossyArray<AdminAssetHealthSignal>.self, forKey: .signals))?.items ?? []
        riskFactors = Self.lines(c, .riskFactors)
        recommendations = Self.lines(c, .recommendations)
        windowDays = (try? c.decodeIfPresent(Int.self, forKey: .windowDays)) ?? 30
        computedAt = (try? c.decodeIfPresent(AriaWireDate.self, forKey: .computedAt))?.value
    }

    private static func lines(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [String] {
        ((try? c.decodeIfPresent([String].self, forKey: key)) ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Un voto buono (≥ 75) è verde; sotto, arancione (mai rosso: non è un errore).
    var isHealthy: Bool { score >= 75 }
}

/// Un segnale che ha concorso al punteggio. `raw_value` (qualunque tipo) non si legge.
nonisolated struct AdminAssetHealthSignal: Decodable, Sendable, Equatable, Identifiable {
    let name: String
    let value: Double?
    let weight: Double?
    let details: String?

    var id: String { name }

    private enum CodingKeys: String, CodingKey { case name, value, weight, details }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = ((try? c.decodeIfPresent(String.self, forKey: .name)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw DecodingError.keyNotFound(CodingKeys.name, .init(codingPath: c.codingPath, debugDescription: "Segnale senza nome"))
        }
        self.name = name
        value = try? c.decodeIfPresent(Double.self, forKey: .value)
        weight = try? c.decodeIfPresent(Double.self, forKey: .weight)
        let details = ((try? c.decodeIfPresent(String.self, forKey: .details)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.details = details.isEmpty ? nil : details
    }
}
