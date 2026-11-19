//
//  AdminUsageStorageBuilder+Notice.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le tredici frasi dell'avviso della scheda dell'archivio (`knowledge.storage` della web): quasi pieno o oltre, per
//  piano (add-on, prova, contratto, nessun piano) e per chi legge (titolare o membro).
//

import Foundation

nonisolated extension AdminUsageStorageBuilder {
    static func notice(tone: AdminUsageTone, wording: Wording, asOwner: Bool, left: String, total: String,
                       over: String, price: String) -> AdminUsageStorageCard.Notice {
        if tone == .over {
            return .init(title: String(localized: "Over your storage limit"),
                         body: overBody(wording: wording, asOwner: asOwner, total: total, over: over, price: price))
        }
        return .init(title: String(localized: "Storage almost full"),
                     body: warnBody(wording: wording, asOwner: asOwner, left: left, total: total, price: price))
    }

    private static func warnBody(wording: Wording, asOwner: Bool, left: String, total: String, price: String) -> String {
        if asOwner {
            switch wording {
            case .bill:
                return String(localized: "You have \(left) left. Past \(total), uploads keep working and extra storage is billed at \(price) / GB / month.")
            case .trial:
                return String(localized: "Your trial includes \(total) and you have \(left) left. Past that, uploads keep working and the owner is notified. Choose a plan to get more room.")
            case .contract:
                return String(localized: "You have \(left) left of the \(total) in your contract. Contact sales to raise it.")
            case .fallback:
                return String(localized: "You have \(left) left. Past \(total), uploads keep working, and extra storage isn't billed while no plan is assigned.")
            }
        }
        return wording == .trial
            ? String(localized: "You have \(left) left of the \(total) in your trial. Uploads keep working past it. Ask an owner to change plan.")
            : String(localized: "You have \(left) left. Ask an owner if your team needs more room.")
    }

    private static func overBody(wording: Wording, asOwner: Bool, total: String, over: String, price: String) -> String {
        if asOwner {
            switch wording {
            case .bill:
                return String(localized: "You're \(over) over \(total). Uploads still work, and the extra is billed at \(price) / GB / month.")
            case .trial:
                return String(localized: "You're \(over) over the \(total) in your trial. Uploads still work and the owner has been notified. Choose a plan to get more room.")
            case .contract:
                return String(localized: "You're \(over) over the \(total) in your contract. Uploads still work; contact sales to update it.")
            case .fallback:
                return String(localized: "You're \(over) over \(total). Uploads still work, and the extra isn't billed while no plan is assigned.")
            }
        }
        switch wording {
        case .trial:
            return String(localized: "Your company is \(over) over the \(total) in its trial. Uploads still work. Ask an owner to change plan.")
        case .contract:
            return String(localized: "Your company is \(over) over the \(total) in its contract. Uploads still work. Ask an owner to contact sales.")
        case .bill, .fallback:
            return String(localized: "Your company is \(over) over its \(total). Uploads still work. Ask an owner about adding storage.")
        }
    }
}
