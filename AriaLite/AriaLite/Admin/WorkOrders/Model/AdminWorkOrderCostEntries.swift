//
//  AdminWorkOrderCostEntries.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le righe dei costi di un ordine: manodopera (/labor), ricambi usati (/parts-used) e costi aggiuntivi
//  (/additional-costs). Le risposte non sono descritte nell'OpenAPI: si leggono con tolleranza, solo l'id
//  è obbligatorio, i numeri possono arrivare come interi, decimali o stringhe e i nomi dei campi hanno
//  qualche alternativa plausibile.
//

import Foundation

/// Una lista che arriva come array o come oggetto che la avvolge (`items`, `data`, `entries`, `results`).
nonisolated struct AdminWorkOrderCostRows<Element: Decodable & Sendable>: Decodable, Sendable {
    var items: [Element]

    private enum CodingKeys: String, CodingKey { case items, data, entries, results }

    init(from decoder: any Decoder) throws {
        if (try? decoder.unkeyedContainer()) != nil {
            items = try AriaLossyArray<Element>(from: decoder).items
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        for key in [CodingKeys.items, .data, .entries, .results] {
            if let rows = try? c.decodeIfPresent(AriaLossyArray<Element>.self, forKey: key) {
                items = rows.items
                return
            }
        }
        items = []
    }
}

/// Una riga di manodopera: chi, quando, quanto e a che tariffa.
nonisolated struct AdminWorkOrderLaborEntry: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var worker: String?
    var startedAt: Date?
    var durationMin: Double?
    var hourlyRate: Double?
    /// Il costo calcolato dal server, se lo manda.
    var serverCost: Double?

    private enum CodingKeys: String, CodingKey {
        case id, worker, workerName, userName, startedAt, durationMin, hourlyRate, cost, totalCost, total
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        worker = f.text(.worker) ?? f.text(.workerName) ?? f.text(.userName)
        startedAt = f.date(.startedAt)
        durationMin = f.double(.durationMin)
        hourlyRate = f.double(.hourlyRate)
        serverCost = f.double(.totalCost) ?? f.double(.cost) ?? f.double(.total)
    }

    /// Minuti per tariffa oraria; quello del server se c'è.
    var cost: Double {
        serverCost ?? (durationMin ?? 0) / 60 * (hourlyRate ?? 0)
    }
}

/// Un ricambio usato nell'ordine.
nonisolated struct AdminWorkOrderPartUsage: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var partId: String?
    var partCode: String?
    var partName: String?
    var unit: String?
    var quantity: Double?
    var unitCost: Double?
    var serverCost: Double?

    private enum CodingKeys: String, CodingKey {
        case id, partId, partCode, code, partName, name, unit, quantity, unitCost, unitPrice, totalCost, cost, total
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        partId = f.id(.partId)
        partCode = f.text(.partCode) ?? f.text(.code)
        partName = f.text(.partName) ?? f.text(.name)
        unit = f.text(.unit)
        quantity = f.double(.quantity)
        unitCost = f.double(.unitCost) ?? f.double(.unitPrice)
        serverCost = f.double(.totalCost) ?? f.double(.cost) ?? f.double(.total)
    }

    /// Quantità per costo unitario; quello del server se c'è.
    var cost: Double {
        serverCost ?? (quantity ?? 0) * (unitCost ?? 0)
    }
}

/// Un costo aggiuntivo (trasporto, servizio esterno, noleggio…).
nonisolated struct AdminWorkOrderCostExtra: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var description: String?
    var value: Double?
    var costCategory: String?
    var createdAt: Date?

    private enum CodingKeys: String, CodingKey { case id, description, value, amount, costCategory, category, createdAt }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        description = f.text(.description)
        value = f.double(.value) ?? f.double(.amount)
        costCategory = f.text(.costCategory) ?? f.text(.category)
        createdAt = f.date(.createdAt)
    }
}

/// Un ricambio del magazzino da scegliere (GET /v1/spare-parts), con giacenza e prezzo.
nonisolated struct AdminWorkOrderPartOption: Decodable, Sendable, Hashable, Identifiable {
    /// L'id del ricambio, o il codice se il server non lo manda.
    let id: String
    var partId: String?
    var code: String
    var name: String
    var unit: String?
    var stockQuantity: Double?
    var minQuantity: Double?
    var unitPrice: Double?
    var nonStock: Bool

    private enum CodingKeys: String, CodingKey { case id, code, name, unit, stockQuantity, minQuantity, unitPrice, nonStock }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let code = f.text(.code) ?? f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.code, .init(codingPath: decoder.codingPath, debugDescription: "code"))
        }
        partId = f.id(.id)
        id = partId ?? code
        self.code = code
        name = f.text(.name) ?? code
        unit = f.text(.unit)
        stockQuantity = f.double(.stockQuantity)
        minQuantity = f.double(.minQuantity)
        unitPrice = f.double(.unitPrice)
        nonStock = f.value(Bool.self, .nonStock) ?? false
    }
}
