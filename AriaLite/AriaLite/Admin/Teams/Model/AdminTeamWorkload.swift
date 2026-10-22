//
//  AdminTeamWorkload.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il carico di una squadra (GET /v1/teams/{id}/workload): capacità, carico, aperti e scaduti, distribuzione per
//  stato, priorità e categoria.
//

import Foundation

/// Una voce di una distribuzione (stato, priorità o categoria) con il suo conteggio.
nonisolated struct AdminTeamCount: Sendable, Hashable, Identifiable {
    let key: String
    let count: Int

    var id: String { key }

    /// Lo schema dice "oggetto di oggetti di interi": si accetta anche un intero diretto. Dentro un oggetto
    /// conta `count` (o `wo_count`, `total`, `n`); in mancanza, il primo numero.
    static func parse(_ json: AriaJSON?) -> [AdminTeamCount] {
        guard let object = json?.objectValue else { return [] }
        return object.compactMap { key, value -> AdminTeamCount? in
            if let number = value.doubleValue, case .number = value { return .init(key: key, count: Int(number)) }
            guard let inner = value.objectValue else { return nil }
            let preferred = ["count", "wo_count", "total", "n"].lazy.compactMap { inner[$0]?.doubleValue }.first
            let number = preferred ?? inner.sorted { $0.key < $1.key }.lazy.compactMap { $0.value.doubleValue }.first
            return number.map { .init(key: key, count: Int($0)) }
        }
        .filter { $0.count > 0 }
        .sorted { ($0.count, $1.key) > ($1.count, $0.key) }
    }
}

nonisolated struct AdminTeamWorkload: Decodable, Sendable, Hashable {
    var capacityMinutesPerWeek: Int
    var loadMinutes: Int
    /// 0 a 100 e oltre quando la squadra è sovraccarica.
    var loadPercent: Double
    var openCount: Int
    var overdueCount: Int
    var byStatus: [AdminTeamCount]
    var byPriority: [AdminTeamCount]
    var byCategory: [AdminTeamCount]
    var specialties: [String]
    var memberCount: Int
    var activeMemberCount: Int

    /// Chiavi in snake_case scritte a mano: la risposta non si converte (le chiavi delle distribuzioni sono
    /// valori, `in_progress` non deve diventare `inProgress`).
    private enum CodingKeys: String, CodingKey {
        case capacityMinutesPerWeek = "capacity_minutes_per_week"
        case loadMinutes = "load_minutes"
        case loadPercent = "load_percent"
        case openCount = "open_wo_count"
        case overdueCount = "overdue_count"
        case byStatus = "by_status"
        case byPriority = "by_priority"
        case byCategory = "by_category"
        case specialties
        case memberCount = "member_count"
        case activeMemberCount = "active_member_count"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func int(_ key: CodingKeys) -> Int { ((try? c.decodeIfPresent(Int.self, forKey: key)) ?? nil) ?? 0 }
        func json(_ key: CodingKeys) -> AriaJSON? { (try? c.decodeIfPresent(AriaJSON.self, forKey: key)) ?? nil }
        capacityMinutesPerWeek = int(.capacityMinutesPerWeek)
        loadMinutes = int(.loadMinutes)
        loadPercent = ((try? c.decodeIfPresent(Double.self, forKey: .loadPercent)) ?? nil) ?? 0
        openCount = int(.openCount)
        overdueCount = int(.overdueCount)
        byStatus = AdminTeamCount.parse(json(.byStatus))
        byPriority = AdminTeamCount.parse(json(.byPriority))
        byCategory = AdminTeamCount.parse(json(.byCategory))
        specialties = ((try? c.decodeIfPresent([String].self, forKey: .specialties)) ?? nil) ?? []
        memberCount = int(.memberCount)
        activeMemberCount = int(.activeMemberCount)
    }

    /// Il carico come testo ("45%").
    var loadText: String { "\(Int(loadPercent.rounded()))%" }

    /// Minuti come ore ("12,5 h"): capacità e carico settimanali.
    static func hoursText(minutes: Int) -> String {
        let hours = (Double(minutes) / 60).formatted(.number.precision(.fractionLength(0...1)))
        return String(localized: "\(hours) h")
    }

    var capacityText: String { Self.hoursText(minutes: capacityMinutesPerWeek) }
    var loadMinutesText: String { Self.hoursText(minutes: loadMinutes) }

    /// Il carico come frazione per la barra, tra 0 e 1.
    var loadFraction: Double { min(max(loadPercent / 100, 0), 1) }
    var isOverloaded: Bool { loadPercent > 100 }
}
