//
//  AdminSparePartPayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body di creazione (SparePartCreate) e modifica (SparePartUpdate). Le chiavi sono in camelCase:
//  l'endpoint `.snakeCased()` le scrive in snake_case.
//

import Foundation

/// POST /v1/spare-parts. `plantId`, `code` e `name` sono obbligatori; i campi `nil` non si mandano.
nonisolated struct AdminSparePartCreate: Encodable, Sendable {
    var code: String
    var name: String
    var category: String?
    var status: String?
    var description: String?
    var manufacturer: String?
    var partNumber: String?
    var compatibleAssetTags: [String]?
    var stockQuantity: Int
    var minQuantity: Int?
    var unit: String?
    var unitPrice: Double?
    var location: String?
    var barcode: String?
    var nonStock: Bool
    var plantId: String
    var vendorId: String?
}

/// PATCH /v1/spare-parts/{id}: solo i campi cambiati. `.null` svuota il campo sul server.
nonisolated struct AdminSparePartUpdate: Encodable, Sendable {
    enum Field: String, CodingKey, Sendable, Hashable {
        case code, name, category, status, description, manufacturer, partNumber, compatibleAssetTags
        case stockQuantity, minQuantity, unit, unitPrice, location, barcode, nonStock, vendorId
    }

    var fields: [Field: AriaJSON] = [:]

    var isEmpty: Bool { fields.isEmpty }

    /// Solo la quantità a magazzino (+/− e "imposta quantità").
    static func stock(_ quantity: Int) -> Self {
        Self(fields: [.stockQuantity: .number(Double(quantity))])
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Field.self)
        for (field, value) in fields { try container.encode(value, forKey: field) }
    }
}
