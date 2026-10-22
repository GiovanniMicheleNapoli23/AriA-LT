//
//  AdminTeam.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una squadra (GET /v1/teams, snake_case): nome, stabilimento, capacità settimanale, se è ad hoc e fino a quando,
//  membri.
//

import Foundation

nonisolated struct AdminTeam: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var name: String
    var description: String?
    var plantId: String?
    var capacityMinutesPerWeek: Int?
    var isAdHoc: Bool
    /// Fine di una squadra ad hoc.
    var expiresAt: Date?
    var members: [AdminTeamMember]

    private enum CodingKeys: String, CodingKey {
        case id, name, description, plantId, capacityMinutesPerWeek, isAdHoc, expiresAt, members
    }

    /// Una riga senza id non si può aprire: si scarta (la lista è `AriaLossyArray`).
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? nil
        plantId = (try? c.decodeIfPresent(String.self, forKey: .plantId)) ?? nil
        capacityMinutesPerWeek = (try? c.decodeIfPresent(Int.self, forKey: .capacityMinutesPerWeek)) ?? nil
        isAdHoc = (try? c.decodeIfPresent(Bool.self, forKey: .isAdHoc)) ?? false
        expiresAt = AriaDate.parse((try? c.decodeIfPresent(String.self, forKey: .expiresAt)) ?? nil)
        members = ((try? c.decodeIfPresent(AriaLossyArray<AdminTeamMember>.self, forKey: .members)) ?? nil)?.items ?? []
    }

    var title: String { name.isEmpty ? String(localized: "Untitled team") : name }

    /// La descrizione, se c'è davvero qualcosa da leggere.
    var trimmedDescription: String? {
        let text = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }

    var activeMemberCount: Int { members.filter(\.active).count }

    /// La squadra ad hoc è scaduta (la web la nasconde dai turni, qui basta segnalarlo).
    func isExpired(at date: Date = .now) -> Bool { expiresAt.map { $0 < date } ?? false }
}
