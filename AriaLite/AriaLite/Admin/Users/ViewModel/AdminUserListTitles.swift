//
//  AdminUserListTitles.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le parole dell'elenco per stato, disponibilità e livello dei filtri (§3.2, §3.3).
//

import Foundation

extension AdminUserStatus {
    /// "Active", "Suspended", "Invited".
    nonisolated var listTitle: String {
        switch self {
        case .active: String(localized: "users.status.active", defaultValue: "Active")
        case .suspended: String(localized: "Suspended")
        case .invited: String(localized: "Invited")
        }
    }
}

extension AdminUserAvailability {
    /// "Available", "Busy", "Off duty".
    nonisolated var listTitle: String {
        switch self {
        case .available: String(localized: "Available")
        case .busy: String(localized: "Busy")
        case .offDuty: String(localized: "Off duty")
        }
    }
}

extension AdminUserFilters.Level {
    /// "Owner", "Has a role", "No role".
    nonisolated var listTitle: String {
        switch self {
        case .owner: String(localized: "Owner")
        case .hasRole: String(localized: "Has a role")
        case .noRole: String(localized: "No role")
        }
    }
}
