//
//  AdminKnowledgeGraphData.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le liste scaricate da cui nasce il grafo. Un tipo non arrivato (403, errore) resta vuoto:
//  le relazioni verso di lui semplicemente non compaiono.
//

import Foundation

struct AdminKnowledgeGraphData {
    var assets: [AdminAsset] = []
    var alarms: [AdminKnowledgeGraphAlarm] = []
    var plans: [AdminKnowledgeGraphMaintenancePlan] = []
    var parts: [AdminSparePart] = []
    var workOrders: [AdminKnowledgeGraphWorkOrder] = []
    var documents: [AdminKnowledgeGraphDocument] = []
    var plants: [AriaPlant] = []
}

/// Chiavi confrontabili: tag, codici e id si scrivono a volte in maiuscolo, a volte no.
nonisolated enum AdminKnowledgeGraphKey {
    static func normalized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty ? nil : value
    }

    static func alarm(_ alarm: AdminKnowledgeGraphAlarm) -> String {
        normalized(alarm.serverId) ?? [alarm.code, alarm.assetTag ?? ""].joined(separator: "|").lowercased()
    }

    static func asset(_ asset: AdminAsset) -> String { asset.tag.lowercased() }
    static func plan(_ plan: AdminKnowledgeGraphMaintenancePlan) -> String { normalized(plan.serverId) ?? plan.name.lowercased() }
    static func part(_ part: AdminSparePart) -> String { part.id.lowercased() }
    static func workOrder(_ order: AdminKnowledgeGraphWorkOrder) -> String { normalized(order.serverId) ?? order.title.lowercased() }
    static func document(_ document: AdminKnowledgeGraphDocument) -> String { normalized(document.serverId) ?? document.displayTitle.lowercased() }
    static func plant(_ plant: AriaPlant) -> String { plant.id.lowercased() }

    /// "in_progress" → "In progress": valori grezzi del server resi leggibili.
    static func humanized(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let spaced = raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }
}
