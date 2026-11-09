//
//  AdminTeamPerson.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una persona dell'azienda (GET /v1/members, snake_case): dà il nome ai membri e le scelte di chi aggiungere.
//

import Foundation

nonisolated struct AdminTeamPerson: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var email: String
    var fullName: String?
    var role: String?
    var isActive: Bool

    private enum CodingKeys: String, CodingKey { case id, email, fullName, role, isActive }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        fullName = (try? c.decodeIfPresent(String.self, forKey: .fullName)) ?? nil
        role = (try? c.decodeIfPresent(String.self, forKey: .role)) ?? nil
        isActive = (try? c.decodeIfPresent(Bool.self, forKey: .isActive)) ?? true
    }

    var displayName: String {
        let name = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty { return name }
        return email.isEmpty ? id : email
    }
}
