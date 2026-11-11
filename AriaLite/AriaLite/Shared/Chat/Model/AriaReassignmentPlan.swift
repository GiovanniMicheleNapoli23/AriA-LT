//
//  AriaReassignmentPlan.swift
//  AriaLite
//
//  Created by Giovanni Michele on 10/11/26.
//
//  I dati della card `reassignment-plan` letti dal JSON dell'artifact: le mosse proposte e il carico
//  delle squadre. Gli id possono arrivare come numeri o come testo; stessi campi della web.
//

import Foundation

nonisolated struct AriaReassignmentPlan: Hashable, Sendable {
    nonisolated struct Move: Identifiable, Hashable, Sendable {
        let woId: String
        let title: String
        let category: String?
        let priority: String?
        let dueDate: Date?
        let estimatedMinutes: Int?
        let assetTag: String?
        let fromTeamName: String?
        let fromLoadPct: Int?
        let toTeamId: String
        let toTeamName: String
        let toLoadPct: Int?
        let toIsAdHoc: Bool
        let motivation: String?

        var id: String { woId }

        /// La scadenza è passata (si confronta con l'inizio di oggi: una scadenza di oggi non è in ritardo).
        func isOverdue(now: Date = .now) -> Bool {
            guard let dueDate else { return false }
            return dueDate < Calendar.current.startOfDay(for: now)
        }
    }

    nonisolated struct TeamLoad: Identifiable, Hashable, Sendable {
        let teamId: String
        let name: String
        let loadPct: Int
        let isAdHoc: Bool

        var id: String { teamId }
        var tone: AriaLoadTone { AriaLoadTone(pct: loadPct) }
    }

    let headline: String?
    let moves: [Move]
    let teams: [TeamLoad]

    /// Una mossa senza ordine o senza squadra di arrivo non si può applicare: si scarta; gli ordini ripetuti contano una volta.
    init(data: [String: AriaJSON]) {
        headline = data["headline"]?.nonEmptyString
        var seen = Set<String>()
        moves = (data["moves"]?.arrayValue ?? []).compactMap { Self.move($0) }.filter { seen.insert($0.woId).inserted }
        var seenTeams = Set<String>()
        teams = (data["team_summary"]?.arrayValue ?? []).compactMap { Self.team($0) }.filter { seenTeams.insert($0.teamId).inserted }
    }

    private static func move(_ m: AriaJSON) -> Move? {
        guard let woId = m["wo_id"]?.nonEmptyString, let toTeamId = m["to_team_id"]?.nonEmptyString else { return nil }
        return Move(
            woId: woId,
            title: m["wo_title"]?.nonEmptyString ?? String(localized: "Work order"),
            category: m["wo_category"]?.nonEmptyString,
            priority: m["wo_priority"]?.nonEmptyString?.lowercased(),
            dueDate: m["wo_due_date"]?.nonEmptyString.flatMap(parseDate),
            estimatedMinutes: m["wo_estimated_duration_min"]?.doubleValue.map { Int($0.rounded()) },
            assetTag: m["wo_asset_tag"]?.nonEmptyString,
            fromTeamName: m["from_team_name"]?.nonEmptyString,
            fromLoadPct: m["from_load_pct"]?.doubleValue.map { Int($0.rounded()) },
            toTeamId: toTeamId,
            toTeamName: m["to_team_name"]?.nonEmptyString ?? toTeamId,
            toLoadPct: m["to_load_pct"]?.doubleValue.map { Int($0.rounded()) },
            toIsAdHoc: m["to_is_ad_hoc"]?.boolValue ?? false,
            motivation: m["motivation"]?.nonEmptyString
        )
    }

    private static func team(_ t: AriaJSON) -> TeamLoad? {
        guard let teamId = t["team_id"]?.nonEmptyString, let name = t["team_name"]?.nonEmptyString else { return nil }
        return TeamLoad(teamId: teamId, name: name, loadPct: t["load_pct"]?.doubleValue.map { Int($0.rounded()) } ?? 0,
                        isAdHoc: t["is_ad_hoc"]?.boolValue ?? false)
    }

    private nonisolated(unsafe) static let withFractions: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private nonisolated(unsafe) static let dateTime = ISO8601DateFormatter()
    private nonisolated(unsafe) static let dayOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    /// "2026-11-10" oppure data e ora ISO 8601 (con o senza frazioni di secondo).
    private static func parseDate(_ text: String) -> Date? {
        withFractions.date(from: text) ?? dateTime.date(from: text) ?? dayOnly.date(from: text)
    }
}

/// Quanto è carica una squadra: mai rosso, il rosso è solo per gli errori.
nonisolated enum AriaLoadTone: Sendable {
    case calm, busy, full

    init(pct: Int) {
        self = pct >= 90 ? .full : pct >= 70 ? .busy : .calm
    }
}
