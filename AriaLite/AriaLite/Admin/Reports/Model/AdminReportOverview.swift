//
//  AdminReportOverview.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I numeri in alto nella pagina Reports (ReportsOverview): ordini, asset, ricambi e piani. Ogni campo ha
//  un valore di partenza: se il server ne omette uno, il riquadro mostra 0.
//

import Foundation

nonisolated struct AdminReportOverview: Decodable, Sendable, Hashable {
    let totalWorkOrders: Int
    let openWorkOrders: Int
    let overdueWorkOrders: Int
    let totalAssets: Int
    let totalSpareParts: Int
    let totalMaintenancePlans: Int

    enum CodingKeys: String, CodingKey {
        case totalWorkOrders = "total_work_orders"
        case openWorkOrders = "open_work_orders"
        case overdueWorkOrders = "overdue_work_orders"
        case totalAssets = "total_assets"
        case totalSpareParts = "total_spare_parts"
        case totalMaintenancePlans = "total_maintenance_plans"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read(_ key: CodingKeys) -> Int {
            if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return value }
            return (try? c.decodeIfPresent(Double.self, forKey: key)).map { Int($0.rounded()) } ?? 0
        }
        totalWorkOrders = read(.totalWorkOrders)
        openWorkOrders = read(.openWorkOrders)
        overdueWorkOrders = read(.overdueWorkOrders)
        totalAssets = read(.totalAssets)
        totalSpareParts = read(.totalSpareParts)
        totalMaintenancePlans = read(.totalMaintenancePlans)
    }

    /// I riquadri nell'ordine della web.
    var tiles: [AdminReportKPI] {
        [
            kpi("total_work_orders", String(localized: "Work orders"), totalWorkOrders, "wrench.and.screwdriver"),
            kpi("open_work_orders", String(localized: "Open"), openWorkOrders, "tray.full"),
            kpi("overdue_work_orders", String(localized: "Overdue"), overdueWorkOrders,
                "exclamationmark.triangle", isAlert: overdueWorkOrders > 0),
            kpi("total_assets", String(localized: "Assets"), totalAssets, "gearshape.2"),
            kpi("total_spare_parts", String(localized: "Spare parts"), totalSpareParts, "shippingbox"),
            kpi("total_maintenance_plans", String(localized: "Maintenance plans"), totalMaintenancePlans,
                "calendar.badge.clock")
        ]
    }

    private func kpi(_ id: String, _ title: String, _ value: Int, _ systemImage: String,
                     isAlert: Bool = false) -> AdminReportKPI {
        AdminReportKPI(id: id, title: title, value: value, systemImage: systemImage, isAlert: isAlert)
    }
}

/// Un riquadro della griglia dei numeri.
nonisolated struct AdminReportKPI: Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let value: Int
    let systemImage: String
    var isAlert = false
}
