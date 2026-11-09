//
//  AdminPurchaseOrder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ordine di acquisto come lo manda il backend (PurchaseOrderResponse) e le sue righe
//  (PurchaseOrderLineResponse). Lettura tollerante: solo `title` è obbligatorio, le date restano testo grezzo
//  e si leggono con i computed `Date?`, lo stato è una enum tollerante (`statusKind`).
//

import Foundation

/// Riga di un ordine: un ricambio (o una descrizione libera) con quantità e costo unitario.
nonisolated struct AdminPurchaseOrderLine: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    var purchaseOrderId: String?
    var partId: String?
    var partCode: String?
    var quantity: Double?
    var unitCost: Double?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, purchaseOrderId, partId, partCode, quantity, unitCost, notes
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        purchaseOrderId = try c.decodeIfPresent(String.self, forKey: .purchaseOrderId)
        partId = try c.decodeIfPresent(String.self, forKey: .partId)
        partCode = try c.decodeIfPresent(String.self, forKey: .partCode)
        quantity = try c.decodeIfPresent(Double.self, forKey: .quantity)
        unitCost = try c.decodeIfPresent(Double.self, forKey: .unitCost)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }

    /// Quantità × costo unitario, quando ci sono entrambi.
    var lineTotal: Double? {
        guard let quantity, let unitCost else { return nil }
        return quantity * unitCost
    }
}

/// Un ordine di acquisto. Lettura tollerante: solo `title` è obbligatorio, le righe mancanti valgono `[]`.
nonisolated struct AdminPurchaseOrder: Decodable, Sendable, Identifiable, Hashable {
    /// Senza id dal backend (non dovrebbe succedere) si usa un UUID locale: l'ordine si mostra ma non si modifica.
    let id: String
    var title: String
    var vendorId: String?
    /// Testo grezzo, di solito "YYYY-MM-DD": il valore leggibile è `orderDateValue`.
    var orderDate: String?
    /// Testo grezzo, di solito "YYYY-MM-DD": il valore leggibile è `expectedDeliveryValue`.
    var expectedDelivery: String?
    var shippingAddress: String?
    var notes: String?
    var plantId: String?
    /// Testo grezzo: il valore tollerante è `statusKind`.
    var status: String?
    var totalCost: Double?
    var approvedBy: String?
    /// ISO 8601 con data e ora: il valore leggibile è `approvedAtValue`.
    var approvedAt: String?
    var lines: [AdminPurchaseOrderLine]
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, vendorId, orderDate, expectedDelivery, shippingAddress, notes, plantId, status
        case totalCost, approvedBy, approvedAt, lines, createdAt, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try c.decode(String.self, forKey: .title)
        vendorId = try c.decodeIfPresent(String.self, forKey: .vendorId)
        orderDate = try c.decodeIfPresent(String.self, forKey: .orderDate)
        expectedDelivery = try c.decodeIfPresent(String.self, forKey: .expectedDelivery)
        shippingAddress = try c.decodeIfPresent(String.self, forKey: .shippingAddress)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        plantId = try c.decodeIfPresent(String.self, forKey: .plantId)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        totalCost = try c.decodeIfPresent(Double.self, forKey: .totalCost)
        approvedBy = try c.decodeIfPresent(String.self, forKey: .approvedBy)
        approvedAt = try c.decodeIfPresent(String.self, forKey: .approvedAt)
        lines = try c.decodeIfPresent([AdminPurchaseOrderLine].self, forKey: .lines) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    /// Lo stato come enum tollerante: uno stato sconosciuto diventa `.unknown`.
    var statusKind: AdminPurchaseOrderStatus { AdminPurchaseOrderStatus(raw: status) }

    var orderDateValue: Date? { AdminPurchaseOrderDates.parse(orderDate) }
    var expectedDeliveryValue: Date? { AdminPurchaseOrderDates.parse(expectedDelivery) }
    var approvedAtValue: Date? { AdminPurchaseOrderDates.parse(approvedAt) }
    var createdAtValue: Date? { AdminPurchaseOrderDates.parse(createdAt) }
    var updatedAtValue: Date? { AdminPurchaseOrderDates.parse(updatedAt) }
}

/// Lettura delle date degli ordini: "YYYY-MM-DD" (giorno, a mezzanotte UTC) oppure ISO 8601 con o senza frazioni.
nonisolated enum AdminPurchaseOrderDates {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.count == 10, let day = dayFormatter.date(from: raw) { return day }
        if let date = AriaDate.parse(raw) { return date }
        // Python a volte scrive i microsecondi (6 cifre): ISO8601DateFormatter ne vuole al massimo 3.
        let trimmed = raw.replacing(/\.(\d{3})\d+/) { ".\($0.output.1)" }
        return AriaDate.parse(trimmed)
    }
}
