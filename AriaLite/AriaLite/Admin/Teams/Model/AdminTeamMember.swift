//
//  AdminTeamMember.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un membro di una squadra (TeamMemberResponse): l'id della riga serve a toglierlo, user_id a trovarne il nome.
//

import Foundation

nonisolated struct AdminTeamMember: Decodable, Sendable, Hashable, Identifiable {
    /// L'id dell'appartenenza (serve a DELETE .../members/{member_id}).
    let membershipId: String?
    let userId: String?
    var roleInTeam: String?
    var active: Bool
    var specialties: [String]

    private enum CodingKeys: String, CodingKey { case id, userId, roleInTeam, active, specialties }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        membershipId = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? nil
        userId = (try? c.decodeIfPresent(String.self, forKey: .userId)) ?? nil
        roleInTeam = (try? c.decodeIfPresent(String.self, forKey: .roleInTeam)) ?? nil
        active = (try? c.decodeIfPresent(Bool.self, forKey: .active)) ?? true
        specialties = (try? c.decodeIfPresent([String].self, forKey: .specialties)) ?? []
        // Senza nessuno dei due id la riga non si può mostrare né togliere.
        if membershipId == nil, userId == nil {
            throw DecodingError.keyNotFound(
                CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
    }

    var id: String { membershipId ?? userId ?? "" }

    var trimmedRole: String? {
        let text = roleInTeam?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }
}
