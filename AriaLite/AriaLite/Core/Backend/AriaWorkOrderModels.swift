//
//  AriaWorkOrderModels.swift
//  AriaLite
//
//  Modelli dei lavori dell'utente mobile (GET /v1/mobile/me, /v1/mobile/work-orders).
//  I valori fissi arrivano come stringhe e si leggono con proprietà tipizzate: un valore
//  nuovo del server non deve far fallire la decodifica dell'intera lista.
//

import Foundation

/// Disponibilità dell'operatore. `available` dura 12 ore e va rinnovato aprendo l'app.
nonisolated enum AriaAvailability: String, Codable, Sendable, CaseIterable {
    case available
    case busy
    case offDuty = "off_duty"

    var localized: String {
        switch self {
        case .available: String(localized: "Available")
        case .busy: String(localized: "Busy")
        case .offDuty: String(localized: "Off duty")
        }
    }

    var systemImage: String {
        switch self {
        case .available: "checkmark.circle.fill"
        case .busy: "minus.circle.fill"
        case .offDuty: "moon.zzz.fill"
        }
    }
}

/// GET /v1/mobile/me e risposta di PUT /v1/mobile/me/availability.
nonisolated struct AriaMobileProfile: Decodable, Sendable, Equatable {
    let id: String
    let name: String
    let username: String
    let specialties: [String]
    /// `nil` se il server manda un valore che l'app non conosce.
    let availability: AriaAvailability?
    let availabilityAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, name, username, specialties, availability, availabilityAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        username = try c.decode(String.self, forKey: .username)
        specialties = try c.decodeIfPresent([String].self, forKey: .specialties) ?? []
        availability = (try c.decodeIfPresent(String.self, forKey: .availability)).flatMap(AriaAvailability.init(rawValue:))
        availabilityAt = try c.decodeIfPresent(AriaWireDate.self, forKey: .availabilityAt)?.value
    }
}

/// Body di PUT /v1/mobile/me/availability: nessun altro campo (il server risponde 422).
nonisolated struct AriaAvailabilityBody: Encodable, Sendable {
    let availability: AriaAvailability
}

nonisolated enum AriaWorkOrderPriority: Int, Sendable, Comparable {
    case low, medium, high

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var localized: String {
        switch self {
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }
}

nonisolated struct AriaWorkOrder: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    /// `reactive` | `preventive`.
    let type: String?
    let category: String?
    /// `high` | `medium` | `low`; gli ordini vecchi possono averlo in maiuscolo.
    let priority: String?
    /// `proposed` | `planned` | `assigned` | `in_progress` | `completed` | `verified` | `cancelled`.
    let status: String
    let assetTag: String?
    let plantId: String?
    let zone: String?
    let scheduledDate: Date?
    let dueDate: Date?
    let estimatedDurationMin: Int?
    let assignedAt: Date?
    /// `auto` | `manual`.
    let assignmentSource: String?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, type, category, priority, status, assetTag, plantId, zone
        case scheduledDate, dueDate, estimatedDurationMin, assignedAt, assignmentSource, notes
        case createdAt, updatedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func date(_ key: CodingKeys) throws -> Date? { try c.decodeIfPresent(AriaWireDate.self, forKey: key)?.value }
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        priority = try c.decodeIfPresent(String.self, forKey: .priority)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        assetTag = try c.decodeIfPresent(String.self, forKey: .assetTag)
        plantId = try c.decodeIfPresent(String.self, forKey: .plantId)
        zone = try c.decodeIfPresent(String.self, forKey: .zone)
        scheduledDate = try date(.scheduledDate)
        dueDate = try date(.dueDate)
        estimatedDurationMin = try c.decodeIfPresent(Int.self, forKey: .estimatedDurationMin)
        assignedAt = try date(.assignedAt)
        assignmentSource = try c.decodeIfPresent(String.self, forKey: .assignmentSource)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try date(.createdAt)
        updatedAt = try date(.updatedAt)
    }

    /// Il confronto è senza maiuscole: finché il server non sistema gli ordini vecchi arrivano `HIGH`, `MEDIUM`.
    var priorityLevel: AriaWorkOrderPriority? {
        switch priority?.lowercased() {
        case "high": .high
        case "medium": .medium
        case "low": .low
        default: nil
        }
    }

    var statusLabel: String {
        switch status {
        case "proposed": String(localized: "Proposed")
        case "planned": String(localized: "Planned")
        case "assigned": String(localized: "Assigned")
        case "in_progress": String(localized: "In progress")
        case "completed": String(localized: "Completed")
        case "verified": String(localized: "Verified")
        case "cancelled": String(localized: "Cancelled")
        default: status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var typeLabel: String? {
        switch type {
        case "reactive": String(localized: "Reactive")
        case "preventive": String(localized: "Preventive")
        default: type?.capitalized
        }
    }

    var assignmentLabel: String? {
        switch assignmentSource {
        case "auto": String(localized: "Automatic")
        case "manual": String(localized: "Manual")
        default: assignmentSource?.capitalized
        }
    }

    var isClosed: Bool {
        ["completed", "verified", "cancelled"].contains(status)
    }

    /// Scaduto e ancora aperto.
    var isOverdue: Bool {
        guard !isClosed, let dueDate else { return false }
        return dueDate < .now
    }
}

/// Data ISO-8601 in UTC con `Z`: le cifre decimali dei secondi variano e possono mancare,
/// quindi non c'è un pattern fisso. Si toglie la frazione (qui non serve) e si legge il resto.
nonisolated struct AriaWireDate: Decodable, Sendable {
    let value: Date?

    init(from decoder: any Decoder) throws {
        value = Self.parse(try decoder.singleValueContainer().decode(String.self))
    }

    static func parse(_ raw: String) -> Date? {
        var text = raw.trimmingCharacters(in: .whitespaces)
        if let dot = text.firstIndex(of: ".") {
            // Frazione di secondo: dal punto alla prima cifra non numerica (Z, +hh:mm).
            let end = text[text.index(after: dot)...].firstIndex { !$0.isNumber } ?? text.endIndex
            text.removeSubrange(dot..<end)
        }
        if let date = AriaDate.parse(text) { return date }
        // Solo data (`2026-10-07`), per tolleranza.
        return try? Date(text, strategy: Date.ISO8601FormatStyle().year().month().day())
    }
}

/// GET /v1/mobile/work-orders: un array di ordini; si accetta anche un oggetto che lo avvolge.
nonisolated struct AriaWorkOrderList: Decodable, Sendable {
    let orders: [AriaWorkOrder]

    private struct Wrapper: Decodable {
        let items: [AriaWorkOrder]?
        let workOrders: [AriaWorkOrder]?
        let data: [AriaWorkOrder]?
    }

    init(from decoder: any Decoder) throws {
        if let array = try? decoder.singleValueContainer().decode([AriaWorkOrder].self) {
            orders = array
        } else {
            let wrapper = try Wrapper(from: decoder)
            orders = wrapper.items ?? wrapper.workOrders ?? wrapper.data ?? []
        }
    }
}
