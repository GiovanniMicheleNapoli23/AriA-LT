//
//  AdminTeamDetailViewModel+Workload.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le distribuzioni del carico (per stato, priorità, categoria) già pronte da disegnare: etichetta, colore,
//  conteggio.
//

import SwiftUI

extension AdminTeamDetailViewModel {
    var statusRows: [AdminTeamDistributionRow] {
        (workload?.byStatus ?? []).map { item in
            let status = AdminTeamWorkOrderStatus(key: item.key)
            let label = status == .unknown ? Self.readable(item.key) : status.label
            return AdminTeamDistributionRow(id: item.key, label: label, tint: status.tint, count: item.count)
        }
    }

    var priorityRows: [AdminTeamDistributionRow] {
        (workload?.byPriority ?? []).map { item in
            let priority = AdminTeamWorkOrderPriority(key: item.key)
            let label = priority == .unknown ? Self.readable(item.key) : priority.label
            return AdminTeamDistributionRow(id: item.key, label: label, tint: priority.tint, count: item.count)
        }
    }

    var categoryRows: [AdminTeamDistributionRow] {
        (workload?.byCategory ?? []).map {
            AdminTeamDistributionRow(id: $0.key, label: Self.readable($0.key), tint: Color.liteAccent, count: $0.count)
        }
    }

    /// `in_progress` → "In progress".
    private static func readable(_ key: String) -> String {
        let text = key.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
