//
//  AdminLearnedKnowledgeMember.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un membro dell'azienda (GET /v1/members, snake_case): serve solo a dare un nome a chi
//  ha proposto o validato un fatto. Si cerca per id o per email.
//

import Foundation

nonisolated struct AdminLearnedKnowledgeMember: Decodable, Sendable, Hashable {
    let id: String?
    let email: String
    let fullName: String?
    let role: String?

    var displayName: String {
        if let name = fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return email
    }

    func matches(_ key: String) -> Bool {
        key == id || key.caseInsensitiveCompare(email) == .orderedSame
    }
}
