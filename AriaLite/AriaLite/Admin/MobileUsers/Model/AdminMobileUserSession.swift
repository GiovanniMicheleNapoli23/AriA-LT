//
//  AdminMobileUserSession.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una sessione di un operatore, cioè un telefono su cui ha fatto l'accesso (MobileSessionResponse, camelCase).
//

import Foundation

nonisolated struct AdminMobileUserSession: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let device: String
    let createdAt: Date?
    let lastActiveAt: Date?

    private enum CodingKeys: String, CodingKey { case id, device, createdAt, lastActiveAt }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }
        id = try c.decode(String.self, forKey: .id)
        device = (try? c.decodeIfPresent(String.self, forKey: .device)) ?? ""
        createdAt = date(.createdAt)
        lastActiveAt = date(.lastActiveAt)
    }
}
