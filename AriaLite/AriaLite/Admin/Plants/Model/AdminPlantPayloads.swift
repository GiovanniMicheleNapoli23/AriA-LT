//
//  AdminPlantPayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body di creazione e modifica di uno stabilimento.
//

import Foundation

nonisolated struct AdminPlantCreate: Encodable, Sendable {
    var name: String
    var code: String
    var description: String?
    var location: String?
}

/// PATCH: il modulo manda sempre tutti i campi, così un campo svuotato (`null`) si cancella davvero.
nonisolated struct AdminPlantUpdate: Encodable, Sendable {
    var name: String
    var code: String
    var description: String?
    var location: String?

    private enum CodingKeys: String, CodingKey {
        case name, code, description, location
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(code, forKey: .code)
        try c.encode(description, forKey: .description)
        try c.encode(location, forKey: .location)
    }
}
