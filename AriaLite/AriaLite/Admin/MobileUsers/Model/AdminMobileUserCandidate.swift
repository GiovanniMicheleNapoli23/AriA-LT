//
//  AdminMobileUserCandidate.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un utente dell'azienda (GET /v1/users, snake_case) che si può promuovere a operatore mobile.
//

import Foundation

nonisolated struct AdminMobileUserCandidate: Decodable, Sendable, Identifiable, Hashable {
    /// Nel contratto può mancare: senza id non si può promuovere.
    let userId: String?
    let email: String
    let fullName: String?
    let role: String?
    let isActive: Bool

    var id: String { userId ?? email }

    var displayName: String {
        if let name = fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return email
    }

    private enum CodingKeys: String, CodingKey { case userId = "id", email, fullName, role, isActive }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = (try? c.decodeIfPresent(AriaFlexibleID.self, forKey: .userId))?.value
        email = try c.decode(String.self, forKey: .email)
        fullName = try? c.decodeIfPresent(String.self, forKey: .fullName)
        role = try? c.decodeIfPresent(String.self, forKey: .role)
        isActive = (try? c.decodeIfPresent(Bool.self, forKey: .isActive)) ?? true
    }
}
