//
//  AriaPeopleRefusal.swift
//  AriaLite
//
//  Created by Giovanni Michele on 12/11/26.
//
//  I codici di rifiuto (`detail.code`) delle rotte delle persone e dell'accesso all'app, con le parole del
//  disegno "Persone nell'app" (§6.6). Si legge il codice, mai il testo del server.
//

import Foundation

nonisolated enum AriaPeopleRefusal: String, Sendable, CaseIterable {
    case alreadyListed = "already_listed"
    case invalidEmail = "invalid_email"
    case labelNotAllowed = "label_not_allowed"
    case notAFieldWorker = "not_a_field_worker"
    case removeMobileAccessFirst = "remove_mobile_access_first"
    case membershipSuspended = "membership_suspended"
    case mobileOperatorElsewhere = "mobile_operator_elsewhere"
    case alreadyMobileOperator = "already_mobile_operator"
    case roleNotAllowed = "role_not_allowed"
    case notInvited = "not_invited"
    case sessionsShared = "sessions_shared"
    case seatLimitReached = "seat_limit_reached"
    case ownerProtected = "owner_protected"
    case mobileStateConflict = "mobile_state_conflict"

    var message: String {
        switch self {
        case .alreadyListed: String(localized: "This person is already in the list.")
        case .invalidEmail: String(localized: "Invalid email address.")
        case .labelNotAllowed: String(localized: "Something went wrong. Try again.")
        case .notAFieldWorker: String(localized: "Turn on Field work first.")
        case .removeMobileAccessFirst: String(localized: "Remove their app access first.")
        case .membershipSuspended: String(localized: "They are suspended in the company: reactivate them first.")
        case .mobileOperatorElsewhere:
            String(localized: "They already use the app for another company: the app can be used for one company at a time.")
        case .alreadyMobileOperator: String(localized: "They already have app access.")
        case .roleNotAllowed: String(localized: "Owners and admins use the app without a seat.")
        case .notInvited: String(localized: "There is no invitation to renew.")
        case .sessionsShared:
            String(localized: "They use the app for another company too: their devices can't be signed out from here.")
        case .seatLimitReached: String(localized: "The app seats are full.")
        case .ownerProtected:
            String(localized: "Only an owner can change an owner's status, and the last owner can't be suspended.")
        case .mobileStateConflict: String(localized: "Their status has changed.")
        }
    }
}
