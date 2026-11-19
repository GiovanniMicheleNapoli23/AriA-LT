//
//  AdminUserDetailViewModel+Confirmations.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le conferme della scheda (§5.3, §5.5, §5.7): il testo di ogni avviso e cosa parte quando si conferma.
//

import Foundation

extension AdminUserDetailViewModel {
    func alert(_ item: AdminUserConfirmation) -> AdminUserAlertContent {
        let name = name
        switch item {
        case .appOff:
            return AdminUserAlertContent(
                title: String(localized: "Turn off \(name)'s app access?"),
                message: String(localized: "\(name) is signed out of the app in this workspace and keeps the web. Any open work orders they hold as a field worker go back to the queue."),
                confirmTitle: String(localized: "Turn off"), isDestructive: true)
        case .fieldOff:
            return AdminUserAlertContent(
                title: String(localized: "Stop \(name) being a field worker?"),
                message: String(localized: "\(name) stops receiving dispatched work, and their open work orders go back to the queue."),
                confirmTitle: String(localized: "Turn off"), isDestructive: true)
        case .suspend:
            return AdminUserAlertContent(
                title: String(localized: "Suspend \(name)?"),
                message: String(localized: "\(name) can't use the web or the app in this workspace until reactivated."),
                confirmTitle: String(localized: "Suspend \(name)"), isDestructive: true)
        case .remove:
            return AdminUserAlertContent(
                title: String(localized: "Remove \(name) from the workspace?"),
                message: String(localized: "\(name) loses access to this workspace. Their records stay."),
                confirmTitle: String(localized: "Remove \(name)"), isDestructive: true)
        case .endSession(let session):
            let device = session.deviceName
            return AdminUserAlertContent(
                title: String(localized: "End this session?"),
                message: String(localized: "\(device) is signed out of this workspace on its next request. Other workspaces keep working. \(name) can sign in again."),
                confirmTitle: String(localized: "End"), isDestructive: true)
        case .endAllSessions:
            return AdminUserAlertContent(
                title: String(localized: "End all of \(name)'s sessions?"),
                message: String(localized: "Every browser and app of \(name) is signed out of this workspace. Other workspaces keep working."),
                confirmTitle: String(localized: "End all sessions"), isDestructive: true)
        }
    }

    /// Il tocco su "conferma" dell'avviso.
    func confirm(_ item: AdminUserConfirmation) {
        confirmation = nil
        switch item {
        case .appOff: Task { await sendAppAccess(false) }
        case .fieldOff: Task { await sendFieldWorker(false) }
        case .suspend: Task { await sendStatus(suspended: true) }
        case .remove: Task { await sendRemove() }
        case .endSession(let session): Task { await endSession(session) }
        case .endAllSessions: Task { await endAllSessions() }
        }
    }
}
