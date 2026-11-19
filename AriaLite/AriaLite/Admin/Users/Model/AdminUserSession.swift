//
//  AdminUserSession.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Una sessione aperta di una persona in questa azienda, web o app (GET …/members/{id}/sessions, §5.5).
//

import Foundation

nonisolated struct AdminUserSession: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    /// `web` o `app`.
    var client: String
    /// Il dispositivo, o vuoto.
    var device: String
    var createdAt: String?
    var lastUsedAt: String?

    init(id: String, client: String, device: String = "", createdAt: String? = nil, lastUsedAt: String? = nil) {
        self.id = id
        self.client = client
        self.device = device
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    private enum CodingKeys: String, CodingKey { case id, client, device, createdAt, lastUsedAt }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? { (try? c.decodeIfPresent(AriaJSON.self, forKey: key))?.nonEmptyString }
        guard let id = text(.id) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Session without id"))
        }
        self.id = id
        client = text(.client) ?? "web"
        device = text(.device) ?? ""
        createdAt = text(.createdAt)
        lastUsedAt = text(.lastUsedAt)
    }

    var isApp: Bool { client == "app" }

    /// "App" o "Browser".
    var clientLabel: String { isApp ? String(localized: "App") : String(localized: "Browser") }

    /// Il dispositivo, o "App"/"Browser" quando non c'è (per la conferma).
    var deviceName: String { device.isEmpty ? clientLabel : device }

    var systemImage: String { isApp ? "iphone" : "globe" }
}
