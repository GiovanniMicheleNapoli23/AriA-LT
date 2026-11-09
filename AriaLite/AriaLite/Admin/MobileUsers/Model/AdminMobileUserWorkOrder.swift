//
//  AdminMobileUserWorkOrder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ordine di lavoro assegnato a un operatore (GET /v1/work-orders, snake_case). Solo i campi che servono
//  a leggerlo nel dettaglio dell'operatore: titolo, stato, priorità, asset, scadenza e avanzamento dei passi.
//

import Foundation

nonisolated struct AdminMobileUserStepProgress: Decodable, Sendable, Hashable {
    let done: Int
    let notDone: Int
    let total: Int

    private enum CodingKeys: String, CodingKey { case done, notDone, total }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        done = (try? c.decodeIfPresent(Int.self, forKey: .done)) ?? 0
        notDone = (try? c.decodeIfPresent(Int.self, forKey: .notDone)) ?? 0
        total = (try? c.decodeIfPresent(Int.self, forKey: .total)) ?? 0
    }
}

nonisolated struct AdminMobileUserWorkOrder: Decodable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    /// `proposed`, `planned`, `assigned`, `in_progress`…
    let status: String
    /// `high`, `medium`, `low`.
    let priority: String
    let assetTag: String?
    let dueDate: Date?
    let scheduledDate: Date?
    let estimatedDurationMin: Int?
    let stepProgress: AdminMobileUserStepProgress?

    /// Etichetta dello stato del lavoro (valori di WorkOrderStatus); uno nuovo si mostra leggibile.
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

    var priorityLevel: AriaWorkOrderPriority? {
        switch priority {
        case "high": .high
        case "medium": .medium
        case "low": .low
        default: nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, status, priority, assetTag, dueDate, scheduledDate, estimatedDurationMin, stepProgress
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func date(_ key: CodingKeys) -> Date? { (try? c.decodeIfPresent(AriaWireDate.self, forKey: key))?.value }
        // Un ordine senza id non si può aprire: la riga si salta (AriaLossyArray).
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        status = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "planned"
        priority = (try? c.decodeIfPresent(String.self, forKey: .priority)) ?? "medium"
        assetTag = try? c.decodeIfPresent(String.self, forKey: .assetTag)
        dueDate = date(.dueDate)
        scheduledDate = date(.scheduledDate)
        estimatedDurationMin = try? c.decodeIfPresent(Int.self, forKey: .estimatedDurationMin)
        stepProgress = try? c.decodeIfPresent(AdminMobileUserStepProgress.self, forKey: .stepProgress)
    }
}
