//
//  AdminAlarmDiagnosis.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  La risposta di POST /v1/agents/diagnostic (DiagnosticAgentResponse): causa, gravità, fiducia, passi di
//  riparazione, ricambi e ordine di lavoro suggerito. L'OpenAPI descrive passi, ricambi e ordine come
//  oggetti liberi: si leggono con tolleranza (vedi AdminAlarmFreeObject), un'etichetta mancante vale assente.
//

import Foundation

nonisolated struct AdminAlarmDiagnosis: Decodable, Sendable, Equatable {
    var alarmCode: String
    var alarmDescription: String
    var rootCause: String
    var severity: String
    /// Fiducia come arriva (0…1 o 0…100): per il testo vedi `confidencePercent`.
    var confidence: Double
    var repairSteps: [AdminAlarmRepairStep]
    var spareParts: [AdminAlarmSparePart]
    var suggestedWorkOrder: AdminAlarmSuggestedWorkOrder?

    private enum CodingKeys: String, CodingKey {
        case alarmCode, alarmDescription, rootCauseAnalysis, severity, confidence
        case repairSteps, sparePartsNeeded, suggestedWorkOrder
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alarmCode = try c.decode(String.self, forKey: .alarmCode)
        alarmDescription = (try? c.decode(String.self, forKey: .alarmDescription)) ?? ""
        rootCause = (try? c.decode(String.self, forKey: .rootCauseAnalysis)) ?? ""
        severity = (try? c.decode(String.self, forKey: .severity)) ?? ""
        confidence = (try? c.decode(Double.self, forKey: .confidence)) ?? 0
        let steps = (try? c.decodeIfPresent([AriaJSON].self, forKey: .repairSteps)) ?? []
        repairSteps = steps.compactMap(AdminAlarmRepairStep.init(json:))
        let parts = (try? c.decodeIfPresent([AriaJSON].self, forKey: .sparePartsNeeded)) ?? []
        spareParts = parts.compactMap(AdminAlarmSparePart.init(json:))
        let order = try? c.decodeIfPresent(AriaJSON.self, forKey: .suggestedWorkOrder)
        suggestedWorkOrder = order.flatMap(AdminAlarmSuggestedWorkOrder.init(json:))
    }

    var confidencePercent: Int {
        let value = confidence <= 1 ? confidence * 100 : confidence
        return Int(min(max(value, 0), 100).rounded())
    }

    /// La gravità in minuscolo, per scegliere colore e priorità.
    var severityKey: String { severity.lowercased() }
}

/// Un oggetto JSON libero con le chiavi normalizzate (senza maiuscole né trattini bassi): il server può
/// mandare `spare_part_name` o `sparePartName`, qui sono la stessa cosa.
nonisolated struct AdminAlarmFreeObject: Sendable {
    private let values: [String: AriaJSON]

    init?(json: AriaJSON) {
        guard case .object(let object) = json else { return nil }
        values = Dictionary(object.map { (Self.normalize($0.key), $0.value) }) { first, _ in first }
    }

    private static func normalize(_ key: String) -> String {
        key.lowercased().replacing("_", with: "")
    }

    /// Il primo valore presente fra le chiavi (già normalizzate).
    func value(_ keys: [String]) -> AriaJSON? {
        keys.lazy.compactMap { values[$0] }.first { $0 != .null }
    }

    func text(_ keys: [String]) -> String? { value(keys)?.nonEmptyString }
}

/// Un passo di riparazione: un testo, o un oggetto con titolo e dettaglio.
nonisolated struct AdminAlarmRepairStep: Sendable, Equatable {
    var title: String
    var detail: String?

    init?(json: AriaJSON) {
        if let text = json.nonEmptyString {
            title = text
            return
        }
        guard let object = AdminAlarmFreeObject(json: json) else { return nil }
        let name = object.text(["title", "name", "step", "action"])
        let description = object.text(["description", "details", "detail", "instruction", "text", "notes"])
        guard let title = name ?? description else { return nil }
        self.title = title
        detail = name == nil ? nil : description
    }
}

/// Un ricambio necessario: nome, codice, quantità e disponibilità, quelli che ci sono.
nonisolated struct AdminAlarmSparePart: Sendable, Equatable {
    var name: String
    var code: String?
    var quantity: String?
    var availability: String?

    init?(json: AriaJSON) {
        if let text = json.nonEmptyString {
            name = text
            return
        }
        guard let object = AdminAlarmFreeObject(json: json),
              let name = object.text(["name", "partname", "description", "part", "title"]) else { return nil }
        self.name = name
        code = object.text(["partnumber", "code", "sku", "partcode", "partid"])
        quantity = object.value(["quantity", "qty", "quantityneeded"])?.stringValue
        availability = Self.availability(object.value(["instock", "available", "availability", "stock", "stocklevel"]))
    }

    private static func availability(_ value: AriaJSON?) -> String? {
        switch value {
        case .bool(let flag)?: flag ? String(localized: "In stock") : String(localized: "Out of stock")
        case let other?: other.nonEmptyString
        case nil: nil
        }
    }
}

/// L'ordine di lavoro che l'agente suggerisce: i campi che servono a precompilare il modulo.
nonisolated struct AdminAlarmSuggestedWorkOrder: Sendable, Equatable {
    var title: String?
    var description: String?
    var priority: String?
    var category: String?
    var assetTag: String?
    var estimatedDurationMin: Int?

    init?(json: AriaJSON) {
        guard let object = AdminAlarmFreeObject(json: json) else { return nil }
        title = object.text(["title", "name", "summary"])
        description = object.text(["description", "details", "notes"])
        priority = object.text(["priority"])?.lowercased()
        category = object.text(["category"])
        assetTag = object.text(["assettag", "asset"])
        estimatedDurationMin = object.value(["estimateddurationmin", "estimatedduration", "durationmin", "duration"])?
            .doubleValue.flatMap { $0.isFinite ? Int($0.rounded()) : nil }
    }
}
