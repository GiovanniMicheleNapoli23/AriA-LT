//
//  AdminExtractionItem.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un elemento da rivedere, di uno dei quattro tipi. Lista, selezione e dettaglio lavorano su questo:
//  id, titolo, riga di riepilogo, stato e confidenza si leggono uguali per tutti.
//

import Foundation

nonisolated enum AdminExtractionItem: Sendable, Hashable, Identifiable {
    case asset(AdminAsset)
    case alarm(AdminExtractionAlarm)
    case plan(AdminExtractionMaintenancePlan)
    case part(AdminSparePart)

    var kind: AdminExtractionKind {
        switch self {
        case .asset: .assets
        case .alarm: .alarms
        case .plan: .maintenancePlans
        case .part: .spareParts
        }
    }

    /// L'id del server: senza, l'elemento si vede ma non si approva né si modifica.
    var serverId: String? {
        switch self {
        case .asset(let asset): asset.serverId
        case .alarm(let alarm): alarm.serverId
        case .plan(let plan): plan.serverId
        case .part(let part): part.id
        }
    }

    /// Unico fra i quattro tipi (selezione, navigazione).
    var id: String {
        switch self {
        case .asset(let asset): "asset:\(asset.id)"
        case .alarm(let alarm): "alarm:\(alarm.serverId ?? alarm.code)"
        case .plan(let plan): "plan:\(plan.serverId ?? plan.name)"
        case .part(let part): "part:\(part.id)"
        }
    }

    var canEdit: Bool { serverId != nil }

    var title: String {
        switch self {
        case .asset(let asset): asset.name
        case .alarm(let alarm): alarm.code
        case .plan(let plan): plan.name
        case .part(let part): part.title
        }
    }

    /// Il codice in piccolo sopra il titolo (tag, codice ricambio), se diverso dal titolo.
    var code: String? {
        switch self {
        case .asset(let asset): asset.tag == asset.name ? nil : asset.tag
        case .alarm: nil
        case .plan(let plan): plan.assetTag
        case .part(let part): part.code.isEmpty || part.code == part.title ? nil : part.code
        }
    }

    var summary: String {
        let parts: [String?] = switch self {
        case .asset(let asset): [asset.typeLabel, asset.zone, asset.manufacturer]
        case .alarm(let alarm): [alarm.description, alarm.assetTag]
        case .plan(let plan): [plan.frequency.map(AdminExtractionPlanFrequency.label(for:)), plan.zone, plan.category]
        case .part(let part): [part.category?.localized, part.manufacturer, part.partNumber]
        }
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var status: String? {
        switch self {
        case .asset(let asset): asset.status
        case .alarm(let alarm): alarm.status
        case .plan(let plan): plan.status
        case .part(let part): part.status?.rawValue
        }
    }

    /// 0…1 (alcuni backend la mandano in percentuale: si riporta in scala).
    var confidence: Double? {
        let raw: Double? = switch self {
        case .asset(let asset): asset.confidence
        case .alarm(let alarm): alarm.confidence
        case .plan(let plan): plan.confidence
        case .part(let part): part.confidence
        }
        guard let raw else { return nil }
        return raw > 1 ? raw / 100 : raw
    }

    var plantId: String? {
        switch self {
        case .asset(let asset): asset.plantId
        case .alarm: nil
        case .plan(let plan): plan.plantId
        case .part(let part): part.plantId
        }
    }

    var updatedAt: Date? {
        switch self {
        case .asset(let asset): asset.updatedAt ?? asset.createdAt
        case .alarm(let alarm): alarm.updatedAt ?? alarm.createdAt
        case .plan(let plan): plan.updatedAt ?? plan.createdAt
        case .part(let part): part.updatedAt ?? part.createdAt
        }
    }

    var isPending: Bool { status.map { AdminExtractionStatus.pending.contains($0) } ?? true }

    /// Il testo in cui cerca la barra di ricerca.
    var searchableFields: [String] { [title, code, summary].compactMap { $0 } }
}
