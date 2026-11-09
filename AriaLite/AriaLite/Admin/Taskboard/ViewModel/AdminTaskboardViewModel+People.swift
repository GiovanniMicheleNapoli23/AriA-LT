//
//  AdminTaskboardViewModel+People.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  La bacheca per persona: chi esegue cosa. Un ordine va alla persona assegnata (o al nome libero), se no
//  alla squadra, se no fra i non assegnati. Prima le persone in ordine alfabetico, poi le squadre, in fondo
//  i non assegnati; dentro ogni gruppo prima le task più urgenti. Filtri e ricerca valgono anche qui.
//

import Foundation

extension AdminTaskboardViewModel {
    /// Le task aperte, divise per chi le esegue.
    var peopleGroups: [AdminTaskboardPersonGroup] {
        personGroups(visibleOrders.filter { !$0.isClosed })
    }

    func personGroups(_ orders: [AdminWorkOrder]) -> [AdminTaskboardPersonGroup] {
        Dictionary(grouping: orders, by: assigneeKey)
            .map { key, orders in
                AdminTaskboardPersonGroup(id: key.id, kind: key.kind, name: key.name,
                                          items: AdminWorkOrderSort.priority.sorted(orders).map(card))
            }
            .sorted { a, b in
                if a.kind != b.kind { return Self.rank(a.kind) < Self.rank(b.kind) }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    private struct AssigneeKey: Hashable {
        let id: String
        let kind: AdminTaskboardPersonGroup.Kind
        let name: String
    }

    private func assigneeKey(_ order: AdminWorkOrder) -> AssigneeKey {
        if let userId = order.assignedToUserId, !userId.isEmpty {
            let name = members.first { $0.id == userId }?.displayName ?? directory.personName(userId)
                ?? order.assignedTo ?? String(localized: "Unknown person")
            return AssigneeKey(id: "user:\(userId)", kind: .person, name: name)
        }
        if let name = order.assignedTo?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return AssigneeKey(id: "name:\(name.lowercased())", kind: .person, name: name)
        }
        if let teamId = order.assignedToTeamId, !teamId.isEmpty {
            return AssigneeKey(id: "team:\(teamId)", kind: .team,
                               name: directory.team(teamId)?.name ?? String(localized: "Unknown team"))
        }
        return AssigneeKey(id: "unassigned", kind: .unassigned, name: String(localized: "Unassigned"))
    }

    private static func rank(_ kind: AdminTaskboardPersonGroup.Kind) -> Int {
        switch kind {
        case .person: 0
        case .team: 1
        case .unassigned: 2
        }
    }
}
