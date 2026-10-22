//
//  AdminWorkOrderFilters.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri e l'ordinamento della lista, come i menu della pagina /work-orders della web. I filtri vanno al
//  server; l'ordinamento si applica alle pagine già scaricate (la rotta non ne ha uno).
//

import Foundation

/// Di chi sono gli ordini mostrati.
nonisolated enum AdminWorkOrderAssigneeFilter: Hashable, Sendable {
    case anyone
    /// L'account collegato (`mobileAccount.id`).
    case me
    case user(String)

    var userId: String? {
        if case .user(let id) = self { return id }
        return nil
    }
}

nonisolated struct AdminWorkOrderFilters: Hashable, Sendable {
    var statusGroup: AdminWorkOrderStatusGroup = .open
    /// Uno stato preciso: il gruppo non conta più (si manda `status_group=all`).
    var status: AdminWorkOrderStatus?
    var priority: AdminWorkOrderPriority?
    var type: AdminWorkOrderType?
    var assignee: AdminWorkOrderAssigneeFilter = .anyone

    /// Quanti filtri oltre al gruppo di stato: il numero sul chip "Filters".
    var extraCount: Int {
        [status != nil, priority != nil, type != nil, assignee != .anyone].filter { $0 }.count
    }

    /// Il gruppo che si manda: con uno stato preciso, tutti (altrimenti "Completed" fra gli aperti è vuoto).
    var effectiveGroup: AdminWorkOrderStatusGroup { status == nil ? statusGroup : .all }

    /// La query della pagina, con l'id dell'utente collegato per "Assigned to me".
    func query(plantId: String?, me: String?, limit: Int, offset: Int) -> AdminWorkOrderQuery {
        AdminWorkOrderQuery(statusGroup: effectiveGroup, status: status, priority: priority, type: type,
                            plantId: plantId, assignedToUserId: assigneeId(me: me), limit: limit, offset: offset)
    }

    func assigneeId(me: String?) -> String? {
        switch assignee {
        case .anyone: nil
        case .me: me
        case .user(let id): id
        }
    }

    /// Lo stesso filtro del server, per un ordine appena salvato.
    func matches(_ order: AdminWorkOrder, me: String?) -> Bool {
        if let priority, order.priority != priority { return false }
        if let type, order.type != type { return false }
        if let status, order.status != status { return false }
        if let id = assigneeId(me: me), order.assignedToUserId != id { return false }
        switch effectiveGroup {
        case .open: return !order.isClosed
        case .closed: return order.isClosed
        case .all: return true
        }
    }
}

/// L'ordine delle righe.
nonisolated enum AdminWorkOrderSort: String, CaseIterable, Identifiable, Sendable {
    /// Come le manda il server.
    case newest
    case dueDate
    case priority
    case updated

    var id: Self { self }

    var title: String {
        switch self {
        case .newest: String(localized: "Newest")
        case .dueDate: String(localized: "Due date")
        case .priority: String(localized: "Priority")
        case .updated: String(localized: "Last updated")
        }
    }

    var systemImage: String {
        switch self {
        case .newest: "clock.arrow.circlepath"
        case .dueDate: "calendar"
        case .priority: "flag"
        case .updated: "pencil.circle"
        }
    }

    /// Ordina restando stabile: a parità vale l'ordine del server.
    func sorted(_ orders: [AdminWorkOrder]) -> [AdminWorkOrder] {
        guard self != .newest else { return orders }
        let indexed = orders.enumerated().map { ($0.offset, $0.element) }
        return indexed.sorted { a, b in
            switch compare(a.1, b.1) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: a.0 < b.0
            }
        }.map(\.1)
    }

    private func compare(_ a: AdminWorkOrder, _ b: AdminWorkOrder) -> ComparisonResult {
        switch self {
        case .newest:
            return .orderedSame
        case .dueDate:
            // Prima la scadenza più vicina; senza scadenza in fondo.
            return Self.compare(a.dueDate, b.dueDate, ascending: true)
        case .priority:
            return Self.compare(Self.rank(a.priority), Self.rank(b.priority), ascending: true)
        case .updated:
            return Self.compare(a.updatedAt ?? a.createdAt, b.updatedAt ?? b.createdAt, ascending: false)
        }
    }

    private static func rank(_ priority: AdminWorkOrderPriority?) -> Int? {
        switch priority {
        case .high?: 0
        case .medium?: 1
        case .low?: 2
        default: nil
        }
    }

    /// I valori mancanti vanno sempre in fondo.
    private static func compare<T: Comparable>(_ a: T?, _ b: T?, ascending: Bool) -> ComparisonResult {
        switch (a, b) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (a?, b?):
            if a == b { return .orderedSame }
            return (a < b) == ascending ? .orderedAscending : .orderedDescending
        }
    }
}
