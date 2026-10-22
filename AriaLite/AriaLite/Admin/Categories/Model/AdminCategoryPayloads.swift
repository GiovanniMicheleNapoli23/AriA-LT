//
//  AdminCategoryPayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body di creazione (CategoryCreate) e modifica (CategoryUpdate). Le chiavi sono in camelCase:
//  l'endpoint `.snakeCased()` le scrive in snake_case.
//

import Foundation

/// POST /v1/categories. `plant_id` è obbligatorio nello schema; i campi opzionali si mandano come `null`
/// quando sono vuoti, per non dipendere dal default del server.
nonisolated struct AdminCategoryCreate: Encodable, Sendable {
    var name: String
    var entityType: String
    var description: String?
    var color: String?
    var icon: String?
    var plantId: String

    private enum CodingKeys: String, CodingKey {
        case name, entityType, description, color, icon, plantId
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(entityType, forKey: .entityType)
        try c.encode(description, forKey: .description)
        try c.encode(color, forKey: .color)
        try c.encode(icon, forKey: .icon)
        try c.encode(plantId, forKey: .plantId)
    }
}

/// PATCH /v1/categories/{id}: solo i campi cambiati. `.null` svuota il campo sul server.
nonisolated struct AdminCategoryUpdate: Encodable, Sendable {
    enum Field: String, CodingKey, Sendable, Hashable {
        case name, entityType, description, color, icon, plantId
    }

    var fields: [Field: AriaJSON] = [:]

    var isEmpty: Bool { fields.isEmpty }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Field.self)
        for (field, value) in fields { try container.encode(value, forKey: field) }
    }
}
