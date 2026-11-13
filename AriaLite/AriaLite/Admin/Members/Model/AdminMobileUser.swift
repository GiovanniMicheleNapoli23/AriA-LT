//
//  AdminMobileUser.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un operatore mobile (MobileUserResponse, chiavi in camelCase). Lettura tollerante: servono id, nome, email
//  e stato; il resto può mancare. Stato e disponibilità restano testo grezzo (vedi AdminMobileUserStatus).
//

import Foundation

nonisolated struct AdminMobileUser: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    /// Valore grezzo: `invited`, `expired`, `active`, `suspended`, `revoked`.
    let status: String
    let specialties: [String]
    /// `available`, `busy`, `off_duty`.
    let availability: String
    let availabilityAt: Date?
    let openCount: Int
    let openMinutes: Int
    let addedAt: Date?
    let invitedUntil: Date?

    var knownStatus: AdminMobileUserStatus? { AdminMobileUserStatus(rawValue: status) }
    var knownAvailability: AdminMobileUserAvailability? { AdminMobileUserAvailability(rawValue: availability) }

    /// Il nome, o l'email se il nome è vuoto.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? email : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, email, status, specialties, availability, availabilityAt
        case openCount, openMinutes, addedAt, invitedUntil
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        specialties = (try? c.decodeIfPresent([String].self, forKey: .specialties)) ?? []
        availability = (try? c.decodeIfPresent(String.self, forKey: .availability)) ?? "off_duty"
        availabilityAt = date(.availabilityAt)
        openCount = (try? c.decodeIfPresent(Int.self, forKey: .openCount)) ?? 0
        openMinutes = (try? c.decodeIfPresent(Int.self, forKey: .openMinutes)) ?? 0
        addedAt = date(.addedAt)
        invitedUntil = date(.invitedUntil)
    }
}
