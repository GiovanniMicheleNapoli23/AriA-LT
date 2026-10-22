//
//  AdminWorkOrderTemplate.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un modello di ordine (WorkOrderTemplateResponse) e i body di creazione e modifica. I ricambi del modello
//  sono oggetti liberi (nessuno schema nell'OpenAPI): si tengono come JSON e si rimandano com'erano.
//  Senza id un modello non si può né modificare né applicare: la riga si scarta.
//

import Foundation

nonisolated struct AdminWorkOrderTemplate: Decodable, Sendable, Hashable, Identifiable {
    let id: String
    var title: String
    var description: String?
    var type: AdminWorkOrderType
    var priority: AdminWorkOrderPriority
    var category: String?
    var zone: String?
    var assetTag: String?
    var estimatedDurationMin: Int?
    var steps: [String]
    var parts: [AriaJSON]
    var plantId: String?
    var updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, type, priority, category, zone, assetTag, estimatedDurationMin, steps, parts
        case plantId, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let f = try AdminWorkOrderFields(decoder, keyedBy: CodingKeys.self)
        guard let id = f.id(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "id"))
        }
        self.id = id
        title = f.text(.title) ?? String(localized: "Untitled template")
        description = f.text(.description)
        type = f.value(AdminWorkOrderType.self, .type) ?? .preventive
        priority = f.value(AdminWorkOrderPriority.self, .priority) ?? .medium
        category = f.text(.category)
        zone = f.text(.zone)
        assetTag = f.text(.assetTag)
        estimatedDurationMin = f.int(.estimatedDurationMin)
        steps = (f.value([String?].self, .steps) ?? []).compactMap { $0 }
        parts = f.value([AriaJSON].self, .parts) ?? []
        plantId = f.id(.plantId)
        updatedAt = f.date(.updatedAt)
    }
}

/// POST /v1/work-order-templates.
nonisolated struct AdminWorkOrderTemplateCreate: Encodable, Sendable {
    var title: String
    var description: String?
    var type: String
    var priority: String
    var category: String?
    var zone: String?
    var assetTag: String?
    var estimatedDurationMin: Int?
    var steps: [String]
    var parts: [AriaJSON]
    var plantId: String
}

/// PATCH /v1/work-order-templates/{id}: si mandano tutti i campi del form; un campo vuoto va come `null`
/// e svuota quello del server.
nonisolated struct AdminWorkOrderTemplateUpdate: Encodable, Sendable {
    var title: String
    var description: String?
    var type: String
    var priority: String
    var category: String?
    var zone: String?
    var assetTag: String?
    var estimatedDurationMin: Int?
    var steps: [String]
    var parts: [AriaJSON]

    private enum CodingKeys: String, CodingKey {
        case title, description, type, priority, category, zone, assetTag, estimatedDurationMin, steps, parts
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(type, forKey: .type)
        try c.encode(priority, forKey: .priority)
        try c.encode(category, forKey: .category)
        try c.encode(zone, forKey: .zone)
        try c.encode(assetTag, forKey: .assetTag)
        try c.encode(estimatedDurationMin, forKey: .estimatedDurationMin)
        try c.encode(steps, forKey: .steps)
        try c.encode(parts, forKey: .parts)
    }
}

/// Un ricambio del modello: il JSON com'è arrivato (o com'è stato scelto) e cosa mostrarne.
nonisolated struct AdminWorkOrderTemplatePart: Identifiable, Hashable, Sendable {
    let id: UUID
    var fields: [String: AriaJSON]

    init(id: UUID = UUID(), fields: [String: AriaJSON]) {
        self.id = id
        self.fields = fields
    }

    /// Un ricambio scelto dal magazzino.
    init(option: AdminWorkOrderPartOption, quantity: Double) {
        var fields: [String: AriaJSON] = [
            "part_code": .string(option.code),
            "name": .string(option.name),
            "quantity": .number(quantity),
        ]
        if let id = option.partId { fields["part_id"] = .string(id) }
        self.init(fields: fields)
    }

    /// Il ricambio di un modello arrivato dal server; `nil` se non è un oggetto.
    init?(json: AriaJSON) {
        guard case .object(let fields) = json else { return nil }
        self.init(fields: fields)
    }

    /// Il valore di un campo, cercato in snake_case e in camelCase (il decoder può aver convertito le chiavi).
    func text(_ snake: String) -> String? {
        let camel = Self.camelCase(snake)
        for key in [snake, camel] {
            switch fields[key] {
            case .string(let value)? where !value.isEmpty: return value
            case .number(let value)?: return value.formatted(.number.precision(.fractionLength(0...2)))
            default: continue
            }
        }
        return nil
    }

    var name: String { text("name") ?? text("part_name") ?? text("part_code") ?? text("code") ?? String(localized: "Part") }
    var code: String? { text("part_code") ?? text("code") }
    var quantity: String? { text("quantity") ?? text("qty") }

    /// Le chiavi tornano in snake_case, qualunque cosa abbia fatto il decoder.
    var json: AriaJSON {
        .object(Dictionary(fields.map { (Self.snakeCase($0.key), $0.value) }) { first, _ in first })
    }

    private static func camelCase(_ snake: String) -> String {
        let parts = snake.split(separator: "_")
        guard let first = parts.first else { return snake }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    private static func snakeCase(_ key: String) -> String {
        key.reduce(into: "") { result, character in
            if character.isUppercase {
                if !result.isEmpty { result.append("_") }
                result.append(contentsOf: character.lowercased())
            } else {
                result.append(character)
            }
        }
    }
}
