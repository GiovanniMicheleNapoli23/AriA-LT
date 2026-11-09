//
//  AdminTeamWorkOrder.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un ordine di lavoro di una squadra (GET /v1/teams/{id}/work-orders). Lo schema del server è libero: si legge
//  dal JSON, riga per riga, senza rompersi se manca un campo.
//

import Foundation

nonisolated struct AdminTeamWorkOrder: Sendable, Hashable, Identifiable {
    let id: String
    var title: String
    var status: AdminTeamWorkOrderStatus
    var priority: AdminTeamWorkOrderPriority
    var assetTag: String?
    var zone: String?
    var category: String?
    var dueDate: Date?
    var teamId: String?
    var assignedUserId: String?

    /// `nil` se la riga non ha un id: si scarta.
    init?(json: AriaJSON) {
        guard let id = json["id"]?.nonEmptyString else { return nil }
        self.id = id
        title = json["title"]?.nonEmptyString ?? String(localized: "Untitled work order")
        status = AdminTeamWorkOrderStatus(key: json["status"]?.stringValue)
        priority = AdminTeamWorkOrderPriority(key: json["priority"]?.stringValue)
        assetTag = json["asset_tag"]?.nonEmptyString
        zone = json["zone"]?.nonEmptyString
        category = json["category"]?.nonEmptyString
        dueDate = AriaDate.parse(json["due_date"]?.nonEmptyString)
        teamId = json["assigned_to_team_id"]?.nonEmptyString
        assignedUserId = json["assigned_to_user_id"]?.nonEmptyString
    }

    /// La risposta è una lista, o un oggetto che la contiene (`items`, `work_orders`, `data`).
    static func rows(from json: AriaJSON) -> [AdminTeamWorkOrder] {
        let list: [AriaJSON]
        if case .array(let items) = json {
            list = items
        } else {
            list = ["items", "work_orders", "data"].lazy.compactMap { json[$0] }.first?.arrayValue ?? []
        }
        return list.compactMap(Self.init(json:))
    }

    var place: String? {
        let parts = [assetTag, zone].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func isOverdue(at date: Date = .now) -> Bool {
        guard let dueDate, !status.isClosed else { return false }
        return dueDate < date
    }
}
