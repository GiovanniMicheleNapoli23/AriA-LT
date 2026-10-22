//
//  AdminAssetWorkOrder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ordine di lavoro di un asset, in sola lettura: quanto basta per la riga nel dettaglio dell'asset
//  (WorkOrderResponse ha molti più campi, qui non servono).
//

import Foundation

nonisolated struct AdminAssetWorkOrder: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let status: String
    let priority: String?
    let type: String?
    let dueDate: Date?
    let completedAt: Date?
    let createdAt: Date?

    var priorityLevel: AriaWorkOrderPriority? {
        switch priority {
        case "low": .low
        case "medium": .medium
        case "high", "urgent", "critical": .high
        default: nil
        }
    }

    var isClosed: Bool { ["completed", "verified", "cancelled"].contains(status) }

    /// Le stesse etichette della lista dei task dell'operatore.
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
        default: type?.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var detailLine: String { [statusLabel, typeLabel].compactMap { $0 }.joined(separator: " · ") }

    /// Chiuso: quando; aperto: la scadenza; altrimenti la creazione.
    var dateText: String? {
        let date = isClosed ? (completedAt ?? createdAt) : (dueDate ?? createdAt)
        return date?.formatted(.dateTime.month(.abbreviated).day())
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, status, priority, type, dueDate, completedAt, completedDate, createdAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func text(_ key: CodingKeys) -> String? {
            guard let value = try? c.decodeIfPresent(AriaFlexibleID.self, forKey: key)?.value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }
        guard let id = text(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: c.codingPath, debugDescription: "Ordine senza id"))
        }
        self.id = id
        title = text(.title) ?? String(localized: "Untitled work order")
        status = text(.status) ?? "planned"
        priority = text(.priority)?.lowercased()
        type = text(.type)
        dueDate = date(.dueDate)
        completedAt = date(.completedAt) ?? date(.completedDate)
        createdAt = date(.createdAt)
    }
}
