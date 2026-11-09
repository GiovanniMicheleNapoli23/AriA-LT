//
//  AdminWorkOrderQuery.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri di GET /v1/work-orders, già pronti come parametri della query.
//

import Foundation

nonisolated struct AdminWorkOrderQuery: Sendable, Hashable {
    var statusGroup: AdminWorkOrderStatusGroup = .open
    var status: AdminWorkOrderStatus?
    var priority: AdminWorkOrderPriority?
    var type: AdminWorkOrderType?
    var assetTag: String?
    var plantId: String?
    var assignedToUserId: String?
    var limit = 50
    var offset = 0

    /// Solo i filtri impostati: gli altri non si mandano.
    var items: [URLQueryItem] {
        let pairs: [(String, String?)] = [
            ("status_group", statusGroup.rawValue),
            ("status", status.flatMap { $0 == .unknown ? nil : $0.rawValue }),
            ("priority", priority.flatMap { $0 == .unknown ? nil : $0.rawValue }),
            ("type", type.flatMap { $0 == .unknown ? nil : $0.rawValue }),
            ("asset_tag", assetTag),
            ("plant_id", plantId),
            ("assigned_to_user_id", assignedToUserId),
            ("limit", String(limit)),
            ("offset", String(offset)),
        ]
        return pairs.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
    }
}
