//
//  AdminMobileUserConfirmation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un'azione che chiede conferma prima di partire: sospendere o togliere un operatore (lista), uscire da un
//  telefono o da tutti (dettaglio). Titolo, spiegazione e pulsante per il dialogo.
//

import Foundation

nonisolated enum AdminMobileUserConfirmation: Sendable, Hashable {
    case suspend(AdminMobileUser)
    case remove(AdminMobileUser)
    case logoutAll(AdminMobileUser)
    case logoutDevice(AdminMobileUser, AdminMobileUserSession)

    var user: AdminMobileUser {
        switch self {
        case .suspend(let user), .remove(let user), .logoutAll(let user), .logoutDevice(let user, _): user
        }
    }

    var title: String {
        switch self {
        case .suspend: String(localized: "Suspend this operator?")
        case .remove: String(localized: "Remove this operator?")
        case .logoutAll: String(localized: "Log out all devices?")
        case .logoutDevice: String(localized: "Log out this device?")
        }
    }

    var message: String {
        switch self {
        case .suspend(let user):
            String(localized: "\(user.displayName) won't be able to use the app until you reactivate them.")
        case .remove(let user):
            String(localized: """
                \(user.displayName) will lose access to the mobile app and free a seat. \
                Their work orders stay as they are.
                """)
        case .logoutAll(let user):
            String(localized: "\(user.displayName) will be signed out everywhere and will need a new sign-in link.")
        case .logoutDevice(_, let session):
            String(localized: "The app on \(session.device) will be signed out.")
        }
    }

    var actionTitle: String {
        switch self {
        case .suspend: String(localized: "Suspend")
        case .remove: String(localized: "Remove")
        case .logoutAll, .logoutDevice: String(localized: "Log out")
        }
    }
}
