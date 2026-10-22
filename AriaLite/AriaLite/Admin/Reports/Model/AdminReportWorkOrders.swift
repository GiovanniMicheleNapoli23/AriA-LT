//
//  AdminReportWorkOrders.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il report degli ordini di lavoro (WOReports): ripartizioni per stato, priorità, categoria e tipo, e
//  l'andamento dei completamenti.
//

import Foundation

nonisolated struct AdminReportWorkOrders: Decodable, Sendable, Hashable {
    let byStatus: [AdminReportBreakdownItem]
    let byPriority: [AdminReportBreakdownItem]
    let byCategory: [AdminReportBreakdownItem]
    let byType: [AdminReportBreakdownItem]
    let trend: [AdminReportTrendPoint]

    enum CodingKeys: String, CodingKey {
        case byStatus = "by_status"
        case byPriority = "by_priority"
        case byCategory = "by_category"
        case byType = "by_type"
        case trend = "completion_trend"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func json(_ key: CodingKeys) -> AriaJSON? { try? c.decodeIfPresent(AriaJSON.self, forKey: key) }
        byStatus = AdminReportBreakdownItem.parse(json(.byStatus))
        byPriority = AdminReportBreakdownItem.parse(json(.byPriority))
        byCategory = AdminReportBreakdownItem.parse(json(.byCategory))
        byType = AdminReportBreakdownItem.parse(json(.byType))
        trend = AdminReportTrend.parse(json(.trend))
    }

    var isEmpty: Bool {
        byStatus.isEmpty && byPriority.isEmpty && byCategory.isEmpty && byType.isEmpty && trend.isEmpty
    }
}
