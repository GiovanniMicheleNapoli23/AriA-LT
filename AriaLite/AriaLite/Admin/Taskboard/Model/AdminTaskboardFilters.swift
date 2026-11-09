//
//  AdminTaskboardFilters.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri della bacheca (squadra, persona, priorità) e la ricerca: si applicano in locale agli
//  ordini già scaricati, così i conteggi delle colonne si aggiornano subito.
//

import Foundation

nonisolated struct AdminTaskboardFilters: Hashable, Sendable {
    var teamId: String?
    var memberId: String?
    var priority: AdminWorkOrderPriority?

    var isActive: Bool { teamId != nil || memberId != nil || priority != nil }

    /// Quanti filtri sono accesi (il numero sul pulsante "Clear").
    var count: Int { [teamId != nil, memberId != nil, priority != nil].filter { $0 }.count }

    func matches(_ order: AdminWorkOrder) -> Bool {
        if let teamId, order.assignedToTeamId != teamId { return false }
        if let memberId, order.assignedToUserId != memberId { return false }
        if let priority, order.priority != priority { return false }
        return true
    }
}
