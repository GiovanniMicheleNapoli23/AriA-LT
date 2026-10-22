//
//  AdminMemberDetails.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I pezzi annidati di un membro: team di oggi (MemberCurrentTeam), carico di lavoro (MemberWorkload) e team di
//  appartenenza (MemberHomeTeam). Lettura tollerante: quel che manca vale come assente.
//

import Foundation

nonisolated struct AdminMemberCurrentTeam: Decodable, Sendable, Hashable {
    let id: String
    let name: String
    let isAdHoc: Bool

    private enum CodingKeys: String, CodingKey { case id, name, isAdHoc }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        isAdHoc = (try? c.decode(Bool.self, forKey: .isAdHoc)) ?? false
    }
}

nonisolated struct AdminMemberWorkload: Decodable, Sendable, Hashable {
    var openCount = 0
    var openMinutes = 0
    var overdueCount = 0

    private enum CodingKeys: String, CodingKey { case openCount, openMinutes, overdueCount }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        openCount = (try? c.decode(Int.self, forKey: .openCount)) ?? 0
        openMinutes = (try? c.decode(Int.self, forKey: .openMinutes)) ?? 0
        overdueCount = (try? c.decode(Int.self, forKey: .overdueCount)) ?? 0
    }

    var isEmpty: Bool { openCount == 0 && openMinutes == 0 && overdueCount == 0 }

    var openText: String { String(localized: "\(openCount) open") }

    var overdueText: String { String(localized: "\(overdueCount) overdue") }

    /// I minuti aperti come durata corta ("2h 30m"); `nil` se non ce ne sono.
    var durationText: String? {
        guard openMinutes > 0 else { return nil }
        return Duration.seconds(openMinutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    /// Una riga sola per la lista: "3 open · 2h 30m".
    var summary: String {
        [openText, durationText].compactMap { $0 }.joined(separator: " · ")
    }
}

nonisolated struct AdminMemberHomeTeam: Decodable, Sendable, Hashable, Identifiable {
    let teamId: String
    let teamName: String
    let roleInTeam: String?
    let isAdHoc: Bool

    var id: String { teamId }

    private enum CodingKeys: String, CodingKey { case teamId, teamName, roleInTeam, isAdHoc }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        teamId = try c.decode(String.self, forKey: .teamId)
        teamName = (try? c.decode(String.self, forKey: .teamName)) ?? ""
        roleInTeam = AdminMemberText.clean(try? c.decodeIfPresent(String.self, forKey: .roleInTeam))
        isAdHoc = (try? c.decode(Bool.self, forKey: .isAdHoc)) ?? false
    }
}

/// Pulizia dei testi in arrivo dal server.
nonisolated enum AdminMemberText {
    /// Il testo senza spazi ai lati, o `nil` se manca o resta vuoto.
    static func clean(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
