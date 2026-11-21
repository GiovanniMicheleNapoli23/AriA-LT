//
//  AdminUserFilters.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La ricerca e i filtri dell'elenco (§3.3): tutto sul telefono, sulle righe già lette. Ogni filtro è facoltativo
//  e si combinano tutti. "Online" è solo dei titolari.
//

import Foundation

nonisolated struct AdminUserFilters: Equatable, Sendable {
    enum Level: String, CaseIterable, Sendable {
        case owner
        case hasRole
        case noRole
    }

    var level: Level?
    /// L'id di un ruolo che compare fra le persone.
    var roleId: String?
    var appAccess: Bool?
    var fieldWorker: Bool?
    var availability: AdminUserAvailability?
    var status: AdminUserStatus?
    /// `true`: online ora; `false`: non online.
    var online: Bool?

    var isEmpty: Bool { self == AdminUserFilters() }

    /// Il testo è contenuto nel nome o nell'email, senza badare alle maiuscole.
    static func matchesSearch(_ row: AdminUserRow, _ query: String) -> Bool {
        matches(row, needle: needle(for: query))
    }

    /// Il testo cercato, ripulito una volta sola per tutte le righe.
    private static func needle(for query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func matches(_ row: AdminUserRow, needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return row.name.lowercased().contains(needle) || (row.email ?? "").lowercased().contains(needle)
    }

    func matches(_ row: AdminUserRow, now: Date) -> Bool {
        switch level {
        case .owner?: if !row.isOwner { return false }
        case .hasRole?: if row.isOwner || row.role == nil { return false }
        case .noRole?: if row.isOwner || row.role != nil { return false }
        case nil: break
        }
        if let roleId, row.role?.id != roleId { return false }
        if let appAccess, row.appAccess != appAccess { return false }
        if let fieldWorker, row.fieldWorker != fieldWorker { return false }
        if let availability, row.availability != availability { return false }
        if let status, row.status != status { return false }
        if let online, AdminUserPresence(row.lastSeen, now: now).isOnline != online { return false }
        return true
    }

    func apply(to people: [AdminUserRow], query: String, now: Date) -> [AdminUserRow] {
        let needle = Self.needle(for: query)
        return people.filter { Self.matches($0, needle: needle) && matches($0, now: now) }
    }
}
