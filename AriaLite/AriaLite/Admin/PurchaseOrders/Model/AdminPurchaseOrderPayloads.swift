//
//  AdminPurchaseOrderPayloads.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body di creazione e modifica degli ordini di acquisto e delle righe. Le chiavi sono in camelCase:
//  l'endpoint `.snakeCased()` le scrive in snake_case.
//

import Foundation

/// POST /v1/purchase-orders. `title` e `plantId` sono obbligatori; i campi `nil` non si mandano.
nonisolated struct AdminPurchaseOrderCreate: Encodable, Sendable {
    var title: String
    var plantId: String
    var vendorId: String?
    var orderDate: String?
    var expectedDelivery: String?
    var shippingAddress: String?
    var notes: String?
}

/// PATCH /v1/purchase-orders/{id}: solo i campi cambiati. `.null` svuota il campo sul server.
nonisolated struct AdminPurchaseOrderUpdate: Encodable, Sendable {
    enum Field: String, CodingKey, Sendable, Hashable {
        case title, vendorId, orderDate, expectedDelivery, shippingAddress, notes, plantId
    }

    var fields: [Field: AriaJSON] = [:]

    var isEmpty: Bool { fields.isEmpty }

    /// Imposta un campo; `nil` lo svuota sul server (manda `null`).
    mutating func set(_ field: Field, _ value: String?) {
        fields[field] = value.map(AriaJSON.string) ?? .null
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Field.self)
        for (field, value) in fields { try container.encode(value, forKey: field) }
    }
}

/// POST /v1/purchase-orders/{id}/lines. Almeno uno tra `partId` e `partCode` identifica il ricambio.
nonisolated struct AdminPurchaseOrderLineCreate: Encodable, Sendable {
    var partId: String?
    var partCode: String?
    var quantity: Double?
    var unitCost: Double?
    var notes: String?
}
