//
//  AdminPlant.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Uno stabilimento come lo dà GET /v1/plants. Il server garantisce id, nome e codice:
//  gli altri campi si leggono solo se ci sono.
//

import Foundation

nonisolated struct AdminPlant: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String
    var code: String
    var description: String?
    var location: String?
    var createdAt: Date?
    var updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, name, code, description, location, createdAt, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = Self.text(c, .id) else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Plant without id")
            throw DecodingError.dataCorrupted(context)
        }
        self.id = id
        name = Self.text(c, .name) ?? ""
        code = Self.text(c, .code) ?? ""
        description = Self.text(c, .description)
        location = Self.text(c, .location)
        createdAt = Self.text(c, .createdAt).flatMap(AriaWireDate.parse)
        updatedAt = Self.text(c, .updatedAt).flatMap(AriaWireDate.parse)
    }

    /// Un campo testuale, senza spazi ai bordi; vuoto o illeggibile diventa `nil`.
    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        guard let value = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
