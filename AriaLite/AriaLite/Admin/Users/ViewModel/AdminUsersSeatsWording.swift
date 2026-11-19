//
//  AdminUsersSeatsWording.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le parole del pannello del tetto (§6.4), come `members.seats` della web: titolo, didascalia, etichette, importo
//  mensile e la nota del piano. Pura: dal `AdminUserSeatsInfo` ai testi. I soldi arrivano `nil` per chi non li può
//  vedere e allora non si scrivono mai (mai 0). Nessun pulsante di piano: sul sito sono email alle vendite.
//

import Foundation

nonisolated struct AdminUsersSeatsWording: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case neutral
        case warning
        case critical
    }

    struct Chip: Equatable, Sendable, Identifiable {
        let text: String
        var tone: Tone = .neutral
        var id: String { text }
    }

    struct Billing: Equatable, Sendable {
        let label: String
        let amount: String
        let caption: String
    }

    struct Alert: Equatable, Sendable {
        let title: String
        let body: String
        let tone: Tone
    }

    /// "4 of 5", o "4 users" senza tetto fisso.
    let headline: String
    /// "users", accanto a "4 of 5".
    let unit: String?
    let caption: String?
    let chips: [Chip]
    let billing: Billing?
    let note: String?
    let alert: Alert?
    /// "No plan is assigned yet; your company runs on Basic."
    let noPlan: String?
    /// La barra dei posti presi (0...1) sotto un tetto fisso.
    let fraction: Double?

    /// "Mobile operators use mobile seats; they don't count as users."
    static var mobileNote: String { String(localized: "Mobile operators use mobile seats; they don't count as users.") }
    /// "Couldn't load your user limits."
    static var errorTitle: String { String(localized: "Couldn't load your user limits.") }
    /// Sotto l'errore: Add user resta acceso, il server controlla il tetto quando la persona viene aggiunta.
    static var errorBody: String { String(localized: "You can still add people. We check the limit when the person is added.") }
    /// Sotto l'avviso del tetto pieno.
    static var addPausedNote: String { String(localized: "Add user is turned off while the company is at its limit.") }

    init(_ info: AdminUserSeatsInfo) {
        let model = AdminUsersSeatsModel(info)
        let money = { Self.money($0, currency: info.currency) }
        let plan = Self.planName(info.planKey)

        if model.hard {
            headline = String(localized: "\(model.used) of \(model.limit)")
            unit = String(localized: "users")
        } else {
            headline = String(localized: "\(model.users) users")
            unit = nil
        }
        let pendingText = String(localized: "\(model.pending) pending invitations")
        if model.pending == 0 {
            caption = nil
        } else if model.hard {
            let activeText = String(localized: "\(model.users) active")
            caption = "\(activeText) · \(pendingText)"
        } else {
            caption = pendingText
        }
        chips = Self.makeChips(info, model)
        fraction = model.fraction
        noPlan = model.fallback ? String(localized: "No plan is assigned yet; your company runs on Basic.") : nil

        if model.layout == .perUser, let billed = money(info.billedAmount), let price = money(info.perUserPrice) {
            billing = Billing(label: String(localized: "Billed each month"), amount: billed,
                              caption: String(localized: "\(model.users) users × \(price)"))
        } else {
            billing = nil
        }
        note = Self.makeNote(info, model, plan: plan, price: money(info.perUserPrice))
        alert = AdminUsersSeatsAlertWording.alert(info, model, plan: plan)
    }

    // MARK: - Etichette

    private static func makeChips(_ info: AdminUserSeatsInfo, _ model: AdminUsersSeatsModel) -> [Chip] {
        switch model.layout {
        case .contract:
            return [Chip(text: String(localized: "Set in your contract"))]
        case .perUser:
            var chips = [Chip(text: String(localized: "\(info.includedUsers ?? 0) included"))]
            if model.extra > 0 && !model.fallback {
                chips.append(Chip(text: String(localized: "\(model.extra) extra users"), tone: .warning))
            }
            return chips
        case .capped, .override, .trial:
            var chips: [Chip]
            if model.used > model.limit {
                chips = [Chip(text: String(localized: "Over the limit"), tone: .critical)]
            } else if model.used == model.limit {
                chips = [Chip(text: String(localized: "Limit reached"), tone: .warning)]
            } else {
                chips = [Chip(text: String(localized: "\(model.left) users left"))]
            }
            if model.layout == .override { chips.append(Chip(text: String(localized: "Set in your contract"))) }
            return chips
        }
    }

    // MARK: - La nota del piano

    private static func makeNote(_ info: AdminUserSeatsInfo, _ model: AdminUsersSeatsModel, plan: String,
                             price: String?) -> String? {
        let included = info.includedUsers ?? 0
        switch model.layout {
        case .perUser:
            if model.fallback {
                return String(localized: "\(plan) includes \(included) users, and you can add more. Nothing is billed while no plan is assigned.")
            }
            guard let price else { return nil }
            return String(localized: "\(plan) is billed per user. \(included) users are included; each extra user adds \(price) a month.")
        case .contract:
            return String(localized: "The user limit for \(plan) is set in your contract.")
        case .trial:
            return String(localized: "Your free trial includes \(model.limit) users. Pending invitations count toward the limit.")
        case .override:
            guard info.includedUsers != nil else {
                return String(localized: "Your contract sets the limit at \(model.limit) users. Pending invitations count toward the limit.")
            }
            return String(localized: "Your contract sets the limit at \(model.limit) users; \(plan) includes \(included). Pending invitations count toward the limit.")
        case .capped:
            return String(localized: "\(plan) includes up to \(model.limit) users. Pending invitations count toward the limit.")
        }
    }

    // MARK: - Piano e soldi

    /// I nomi pubblici dei piani (`auth.login.plans.tiers` della web); una chiave sconosciuta si legge ripulita.
    static func planName(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return String(localized: "Your plan") }
        switch key {
        case "basic": return "Basic"
        case "basic_plus": return "Basic Plus"
        case "professional": return "Professional"
        case "enterprise": return "Enterprise"
        case "enterprise_ar_plus": return "Enterprise AR+"
        case "free_demo": return "Free Demo"
        default: return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Un importo decimale del server ("1200") in valuta; `nil` se manca l'importo o la valuta (mai 0).
    static func money(_ amount: String?, currency: String?) -> String? {
        guard let amount, let currency, !currency.isEmpty,
              let value = Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return value.formatted(.currency(code: currency.uppercased()).precision(.fractionLength(0...2)))
    }
}
