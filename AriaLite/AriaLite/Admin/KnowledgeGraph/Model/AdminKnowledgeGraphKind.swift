//
//  AdminKnowledgeGraphKind.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I tipi di entità del grafo, nell'ordine della panoramica: nome, plurale e icona di ciascuno.
//

import Foundation

nonisolated enum AdminKnowledgeGraphKind: String, CaseIterable, Sendable, Hashable, Identifiable {
    case asset, alarm, maintenancePlan, sparePart, workOrder, document, plant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .asset: String(localized: "Asset")
        case .alarm: String(localized: "Alarm")
        case .maintenancePlan: String(localized: "Maintenance plan")
        case .sparePart: String(localized: "Spare part")
        case .workOrder: String(localized: "Work order")
        case .document: String(localized: "Document")
        case .plant: String(localized: "Plant")
        }
    }

    var pluralTitle: String {
        switch self {
        case .asset: String(localized: "Assets")
        case .alarm: String(localized: "Alarms")
        case .maintenancePlan: String(localized: "Maintenance plans")
        case .sparePart: String(localized: "Spare parts")
        case .workOrder: String(localized: "Work orders")
        case .document: String(localized: "Documents")
        case .plant: String(localized: "Plants")
        }
    }

    var systemImage: String {
        switch self {
        case .asset: "gearshape.2"
        case .alarm: "exclamationmark.triangle"
        case .maintenancePlan: "calendar.badge.clock"
        case .sparePart: "shippingbox"
        case .workOrder: "wrench.and.screwdriver"
        case .document: "doc.text"
        case .plant: "building.2"
        }
    }
}
