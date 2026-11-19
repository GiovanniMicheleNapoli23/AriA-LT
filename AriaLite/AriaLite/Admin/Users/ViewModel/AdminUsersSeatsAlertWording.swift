//
//  AdminUsersSeatsAlertWording.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso del pannello del tetto quando un tetto fisso è pieno o superato (`seatAlert` di `seat-model.ts`): le
//  parole seguono il piano (prova, contratto, passaggio al piano successivo con o senza importo, vendite). Solo
//  testo: i pulsanti del sito sono email alle vendite e nell'app non ci sono.
//

import Foundation

nonisolated enum AdminUsersSeatsAlertWording {
    static func alert(_ info: AdminUserSeatsInfo, _ model: AdminUsersSeatsModel, plan: String) -> AdminUsersSeatsWording.Alert? {
        switch model.state {
        case .open: nil
        case .reached: reached(info, model, plan: plan)
        case .over: over(info, model, plan: plan)
        }
    }

    /// Il nome del piano successivo, la sua capienza e il prezzo (`nil` se il server non lo manda).
    private static func nextPlan(_ info: AdminUserSeatsInfo) -> (name: String, limit: Int, price: String?)? {
        guard let next = info.next else { return nil }
        return (AdminUsersSeatsWording.planName(next.planKey), next.includedUsers ?? 0,
                AdminUsersSeatsWording.money(next.price, currency: info.currency))
    }

    private static func reached(_ info: AdminUserSeatsInfo, _ model: AdminUsersSeatsModel,
                                plan: String) -> AdminUsersSeatsWording.Alert {
        let limit = model.limit
        let pending = model.pending > 0
        let title = String(localized: "You've reached the user limit")
        let body: String
        if model.layout == .trial {
            body = pending
                ? String(localized: "Your free trial includes \(limit) users, and pending invitations count. Revoke a pending invitation, or choose a plan.")
                : String(localized: "Your free trial includes \(limit) users. Choose a plan to add more.")
        } else if model.layout == .override {
            body = pending
                ? String(localized: "Your contract sets the limit at \(limit) users, and pending invitations count. Revoke a pending invitation, or contact sales to change your contract.")
                : String(localized: "Your contract sets the limit at \(limit) users. Contact sales to change your contract and add more.")
        } else if let next = nextPlan(info), let price = next.price {
            body = pending
                ? String(localized: "\(plan) includes \(limit) users, and pending invitations count. Revoke a pending invitation, or upgrade to \(next.name) (\(price) a month, up to \(next.limit) users).")
                : String(localized: "\(plan) includes \(limit) users. Upgrade to \(next.name) (\(price) a month, up to \(next.limit) users) to add more.")
        } else if let next = nextPlan(info) {
            body = pending
                ? String(localized: "\(plan) includes \(limit) users, and pending invitations count. Revoke a pending invitation, or upgrade to \(next.name) (up to \(next.limit) users).")
                : String(localized: "\(plan) includes \(limit) users. Upgrade to \(next.name) (up to \(next.limit) users) to add more.")
        } else {
            body = pending
                ? String(localized: "\(plan) includes \(limit) users, and pending invitations count. Revoke a pending invitation, or contact sales about Enterprise.")
                : String(localized: "\(plan) includes \(limit) users. Contact sales about Enterprise to add more.")
        }
        return .init(title: title, body: body, tone: .warning)
    }

    private static func over(_ info: AdminUserSeatsInfo, _ model: AdminUsersSeatsModel,
                             plan: String) -> AdminUsersSeatsWording.Alert {
        let limit = model.limit
        let users = model.users
        if model.layout == .trial {
            return .init(title: String(localized: "You have more users than your plan includes"),
                         body: String(localized: "Your free trial includes \(limit) users and your company has \(users). Everyone keeps their access, but new invitations are paused until you are within the limit or choose a plan."),
                         tone: .critical)
        }
        if model.layout == .override {
            return .init(title: String(localized: "You have more users than your contract allows"),
                         body: String(localized: "Your contract sets the limit at \(limit) users and your company has \(users). Everyone keeps their access, but new invitations are paused until you are within the limit. Contact sales to change your contract."),
                         tone: .critical)
        }
        let title = String(localized: "You have more users than your plan includes")
        if let next = nextPlan(info) {
            return .init(title: title,
                         body: String(localized: "\(plan) includes \(limit) users and your company has \(users). Everyone keeps their access, but new invitations are paused until you are within the limit or upgrade to \(next.name)."),
                         tone: .critical)
        }
        return .init(title: title,
                     body: String(localized: "\(plan) includes \(limit) users and your company has \(users). Everyone keeps their access, but new invitations are paused until you are within the limit. Contact sales about Enterprise."),
                     tone: .critical)
    }
}
