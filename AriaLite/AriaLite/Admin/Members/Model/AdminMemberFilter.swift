//
//  AdminMemberFilter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri dell'elenco dei membri: stato (attivo / non attivo) e le voci dei menu di filtro.
//

import Foundation

nonisolated enum AdminMemberStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case active, inactive

    var id: String { rawValue }

    var localized: String {
        switch self {
        case .active: String(localized: "Active")
        case .inactive: String(localized: "Inactive")
        }
    }

    func matches(_ member: AdminMember) -> Bool {
        switch self {
        case .active: member.isActive
        case .inactive: !member.isActive
        }
    }
}

/// Una voce di un menu di filtro: chiave, testo e quanti membri la rispettano.
nonisolated struct AdminMemberFilterOption: Identifiable, Hashable, Sendable {
    let key: String
    let label: String
    let count: Int

    var id: String { key }
}
