//
//  AdminMemberFilter.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I filtri dell'elenco dei membri: stato (da `access`), le chiavi speciali del filtro per ruolo e le voci dei
//  menu di filtro.
//

import Foundation

/// Lo stato in azienda e nell'app, letto da `access` (mai da `isActive`: i sospesi ora compaiono nell'elenco).
nonisolated enum AdminMemberStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case active, suspended, appActive, appInvited, appSuspended

    var id: String { rawValue }

    var localized: String {
        switch self {
        case .active: String(localized: "Active")
        case .suspended: String(localized: "Suspended")
        case .appActive: String(localized: "App active")
        case .appInvited: String(localized: "Invited to the app")
        case .appSuspended: String(localized: "App suspended")
        }
    }

    func matches(_ member: AdminMember) -> Bool {
        switch self {
        case .active: !member.isSuspendedInCompany
        case .suspended: member.isSuspendedInCompany
        case .appActive: member.access == .operator
        case .appInvited: member.access == .operatorInvited
        case .appSuspended: member.access == .operatorSuspended
        }
    }
}

/// Le chiavi del filtro per ruolo che non sono l'id di un ruolo.
nonisolated enum AdminMemberRoleFilter {
    /// Titolari e admin (non hanno un ruolo di Roles & Rights).
    static let ownersAndAdmins = "owners_admins"
    /// Chi non è titolare né admin e non ha un ruolo.
    static let noRole = "no_role"

    /// La persona rispetta la chiave: un id di ruolo, oppure una delle due speciali.
    static func matches(_ key: String, _ member: AdminMember) -> Bool {
        switch key {
        case ownersAndAdmins: member.isOwnerOrAdmin
        case noRole: member.isRegularMember && member.accessRole == nil
        default: member.accessRole?.id == key
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
