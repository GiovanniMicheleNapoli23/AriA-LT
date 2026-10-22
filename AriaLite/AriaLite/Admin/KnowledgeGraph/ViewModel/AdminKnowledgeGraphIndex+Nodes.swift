//
//  AdminKnowledgeGraphIndex+Nodes.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come ogni entità diventa un nodo: titolo, righe sotto, stato e testi per la ricerca.
//  Lo stato si mostra solo quando dice qualcosa (le liste arrivano già filtrate sugli "approved").
//

import Foundation

extension AdminKnowledgeGraphIndex {
    private typealias K = AdminKnowledgeGraphKey

    func node(asset: AdminAsset, key: String) -> AdminKnowledgeGraphNode {
        AdminKnowledgeGraphNode(ref: Ref(kind: .asset, key: key), title: asset.tag,
                                subtitle: asset.name == asset.tag ? nil : asset.name,
                                detail: asset.summaryLine.isEmpty ? nil : asset.summaryLine,
                                status: asset.status == "approved" ? nil : asset.statusLabel,
                                searchable: asset.searchableFields + [asset.zone].compactMap { $0 })
    }

    func node(alarm: AdminKnowledgeGraphAlarm, key: String) -> AdminKnowledgeGraphNode {
        AdminKnowledgeGraphNode(ref: Ref(kind: .alarm, key: key), title: alarm.code,
                                subtitle: alarm.description,
                                detail: Self.line([alarm.assetTag, K.humanized(alarm.category), alarm.zone]),
                                status: Self.unusualStatus(alarm.status),
                                searchable: [alarm.code, alarm.description, alarm.assetTag, alarm.category].compactMap { $0 })
    }

    func node(plan: AdminKnowledgeGraphMaintenancePlan, key: String) -> AdminKnowledgeGraphNode {
        let due = plan.nextDueAt.map { String(localized: "Next due \($0.formatted(date: .abbreviated, time: .omitted))") }
        return AdminKnowledgeGraphNode(ref: Ref(kind: .maintenancePlan, key: key), title: plan.name,
                                       subtitle: Self.line([K.humanized(plan.frequency), plan.assetTag]),
                                       detail: due,
                                       status: Self.unusualStatus(plan.status),
                                       searchable: [plan.name, plan.description, plan.category].compactMap { $0 } + plan.allAssetTags)
    }

    func node(part: AdminSparePart, key: String) -> AdminKnowledgeGraphNode {
        let unit = part.unit.map { " \($0)" } ?? ""
        let stock = part.nonStock ? String(localized: "Non-stock item") : String(localized: "Stock: \(part.stockQuantity)\(unit)")
        return AdminKnowledgeGraphNode(ref: Ref(kind: .sparePart, key: key), title: part.name.isEmpty ? part.code : part.name,
                                       subtitle: Self.line([part.name.isEmpty ? nil : part.code, part.partNumber]),
                                       detail: stock,
                                       status: part.status.flatMap { $0 == .approved ? nil : $0.localized },
                                       searchable: [part.name, part.code, part.partNumber, part.manufacturer].compactMap { $0 })
    }

    func node(workOrder order: AdminKnowledgeGraphWorkOrder, key: String) -> AdminKnowledgeGraphNode {
        let due = order.dueDate.map { String(localized: "Due \($0.formatted(date: .abbreviated, time: .omitted))") }
        return AdminKnowledgeGraphNode(ref: Ref(kind: .workOrder, key: key), title: order.title,
                                       subtitle: Self.line([order.assetTag, K.humanized(order.priority)]),
                                       detail: due ?? order.zone,
                                       status: K.humanized(order.status),
                                       searchable: [order.title, order.serverId, order.assetTag, order.alarmCode].compactMap { $0 })
    }

    func node(document: AdminKnowledgeGraphDocument, key: String) -> AdminKnowledgeGraphNode {
        let file = document.fileName == document.displayTitle ? nil : document.fileName
        return AdminKnowledgeGraphNode(ref: Ref(kind: .document, key: key), title: document.displayTitle,
                                       subtitle: file ?? K.humanized(document.sourceType),
                                       detail: document.tags.isEmpty ? nil : document.tags.joined(separator: ", "),
                                       status: K.humanized(document.ingestionState),
                                       searchable: [document.title, document.fileName, document.description].compactMap { $0 } + document.tags)
    }

    func node(plant: AriaPlant, key: String) -> AdminKnowledgeGraphNode {
        AdminKnowledgeGraphNode(ref: Ref(kind: .plant, key: key), title: plant.name,
                                subtitle: Self.line([plant.code, plant.location]),
                                searchable: [plant.name, plant.code, plant.location].compactMap { $0 })
    }

    /// Le parti presenti unite da " · "; `nil` se non ce n'è nessuna.
    static func line(_ parts: [String?]) -> String? {
        let present = parts.compactMap { $0 }.filter { !$0.isEmpty }
        return present.isEmpty ? nil : present.joined(separator: " · ")
    }

    private static func unusualStatus(_ raw: String?) -> String? {
        raw == nil || raw == "approved" ? nil : K.humanized(raw)
    }
}
