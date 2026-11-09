//
//  AdminVendorPayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body di creazione (VendorCreate) e modifica (VendorUpdate). Le chiavi sono in camelCase:
//  l'endpoint `.snakeCased()` le scrive in snake_case.
//

import Foundation

/// POST /v1/vendors. Solo `name` è obbligatorio; i campi `nil` non si mandano.
nonisolated struct AdminVendorCreate: Encodable, Sendable {
    var name: String
    var companyName: String?
    var email: String?
    var phone: String?
    var website: String?
    var address: String?
    var city: String?
    var country: String?
    var vendorType: String?
    var rating: Double?
    var notes: String?
    var plantId: String?
}

/// PATCH /v1/vendors/{id}: solo i campi cambiati. `.null` svuota il campo sul server.
/// Lo stabilimento non si sposta da qui.
nonisolated struct AdminVendorUpdate: Encodable, Sendable {
    enum Field: String, CodingKey, Sendable, Hashable {
        case name, companyName, email, phone, website, address, city, country, vendorType, rating, notes
    }

    var fields: [Field: AriaJSON] = [:]

    var isEmpty: Bool { fields.isEmpty }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Field.self)
        for (field, value) in fields { try container.encode(value, forKey: field) }
    }
}
