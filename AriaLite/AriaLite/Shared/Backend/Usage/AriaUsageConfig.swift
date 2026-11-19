//
//  AriaUsageConfig.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  GET /v1/usage/config: il piano, i livelli di impegno e il peso in crediti di ogni azione. L'app non tiene nessuna
//  cifra sua. Lettura tollerante: ogni campo si decodifica da solo, uno illeggibile vale `nil` o il suo valore di
//  riposo e non fa fallire il payload; le chiavi sconosciute si ignorano.
//

import Foundation

/// La prova gratuita (`trial`): presente solo in prova, mai dedotta dal nome del piano.
nonisolated struct AriaUsageTrial: Decodable, Sendable, Hashable {
    var startsOn: String?
    var endsOn: String?
    var daysLeft: Int?

    private enum CodingKeys: String, CodingKey {
        case startsOn = "starts_on", endsOn = "ends_on", daysLeft = "days_left"
    }

    init(startsOn: String? = nil, endsOn: String? = nil, daysLeft: Int? = nil) {
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.daysLeft = daysLeft
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startsOn = c.ariaLenient(.startsOn)
        endsOn = c.ariaLenient(.endsOn)
        daysLeft = c.ariaWhole(.daysLeft)
    }
}

nonisolated struct AriaUsageConfig: Decodable, Sendable, Equatable {
    nonisolated struct Plan: Decodable, Sendable, Equatable {
        var tier: String?
        /// Crediti al giorno; `nil` su un piano a pool.
        var creditsPerDay: Decimal?
        var creditPoolPerCycle: Decimal?

        private enum CodingKeys: String, CodingKey {
            case tier, creditsPerDay = "credits_per_day", creditPoolPerCycle = "credit_pool_per_cycle"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            tier = c.ariaLenient(.tier)
            creditsPerDay = c.ariaDecimal(.creditsPerDay)
            creditPoolPerCycle = c.ariaDecimal(.creditPoolPerCycle)
        }
    }

    nonisolated struct Level: Decodable, Sendable, Equatable {
        var multiplier: Decimal?
        /// Il piano può usare il livello.
        var available = false
        /// Il badge "High use".
        var warning = false
        /// La chiave del piano che lo sblocca (`professional`…).
        var unlockTier: String?

        private enum CodingKeys: String, CodingKey {
            case multiplier, available, warning, unlockTier = "unlock_tier"
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            multiplier = c.ariaDecimal(.multiplier)
            available = c.ariaLenient(.available) ?? false
            warning = c.ariaLenient(.warning) ?? false
            unlockTier = c.ariaLenient(.unlockTier)
        }
    }

    nonisolated struct Effort: Decodable, Sendable, Equatable {
        /// Il livello da cui parte una conversazione nuova.
        var defaultLevel: AriaEffortLevel?
        /// Il controllo esiste solo se qui c'è `chat.reply`.
        var enabledActions: [String] = []
        /// Le chiavi sconosciute si scartano.
        var levels: [AriaEffortLevel: Level] = [:]

        private enum CodingKeys: String, CodingKey {
            case defaultLevel = "default_level", enabledActions = "enabled_actions", levels
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            defaultLevel = c.ariaLenient(String.self, .defaultLevel).flatMap(AriaEffortLevel.init(rawValue:))
            enabledActions = c.ariaLenient([String].self, .enabledActions) ?? []
            let raw = c.ariaLenient([String: AriaLenient<Level>].self, .levels) ?? [:]
            levels = raw.reduce(into: [:]) { result, entry in
                if let level = AriaEffortLevel(rawValue: entry.key), let info = entry.value.value {
                    result[level] = info
                }
            }
        }
    }

    nonisolated struct Action: Decodable, Sendable, Equatable {
        var creditWeight: Decimal?

        private enum CodingKeys: String, CodingKey { case creditWeight = "credit_weight" }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            creditWeight = c.ariaDecimal(.creditWeight)
        }
    }

    var currency: String?
    var tierSource: String?
    var amountsVisible = false
    var canManagePlan = false
    var plan: Plan?
    var effort: Effort?
    var actions: [String: Action] = [:]
    /// Il passo di arrotondamento dell'addebito ("0.1"); `nil` su un server vecchio: nessuna cifra calcolata.
    var chargeRoundingIncrement: Decimal?
    /// `ui.credit_note_mode`: "off" nasconde la nota sotto la risposta.
    var creditNoteMode: String?
    /// `ui.sales_contact_email`: l'indirizzo per scegliere un piano.
    var salesContactEmail: String?
    /// `billing.customer_visibility`: serve per il tag "Extra credits".
    var customerVisibility = false
    var trial: AriaUsageTrial?
    /// `overage.at_spend_cap`: "degrade" o "stop".
    var atSpendCap: String?
    /// `overage.price_per_credit`: euro per credito extra; `nil` per chi non vede i soldi (mai 0).
    var pricePerCredit: Decimal?
    /// `overage.spend_cap_default_eur`: il tetto sempre attivo del piano; `nil` lascia il tetto facoltativo.
    var spendCapDefaultEur: Decimal?
    /// `ui.projection_window_days`: i giorni su cui il server calcola la proiezione.
    var projectionWindowDays: Int?
    /// `notifications.email_enabled`: gli avvisi arrivano anche per email. Su un server vecchio: `false`.
    var emailNotificationsEnabled = false
    /// I piani in ordine di rango (dal più basso). Servono per "Upgrade to {plan}" e per Live Talk (vedi `+Tiers`).
    var tiers: [AriaUsageTier] = []

    private enum CodingKeys: String, CodingKey {
        case currency, plan, effort, actions, ui, billing, trial, overage, tiers, notifications
        case tierSource = "tier_source", amountsVisible = "amounts_visible", canManagePlan = "can_manage_plan"
        case chargeRoundingIncrement = "charge_rounding_increment"
    }

    private enum UIKeys: String, CodingKey {
        case creditNoteMode = "credit_note_mode", salesContactEmail = "sales_contact_email"
        case projectionWindowDays = "projection_window_days"
    }

    private enum BillingKeys: String, CodingKey { case customerVisibility = "customer_visibility" }
    private enum OverageKeys: String, CodingKey {
        case atSpendCap = "at_spend_cap", pricePerCredit = "price_per_credit", spendCapDefaultEur = "spend_cap_default_eur"
    }

    private enum NotificationsKeys: String, CodingKey { case emailEnabled = "email_enabled" }

    /// Una configurazione vuota: nessun livello, nessuna azione.
    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currency = c.ariaLenient(.currency)
        tierSource = c.ariaLenient(.tierSource)
        amountsVisible = c.ariaLenient(.amountsVisible) ?? false
        canManagePlan = c.ariaLenient(.canManagePlan) ?? false
        plan = c.ariaLenient(.plan)
        effort = c.ariaLenient(.effort)
        actions = (c.ariaLenient([String: AriaLenient<Action>].self, .actions) ?? [:]).compactMapValues(\.value)
        chargeRoundingIncrement = c.ariaDecimal(.chargeRoundingIncrement)
        if let ui = try? c.nestedContainer(keyedBy: UIKeys.self, forKey: .ui) {
            creditNoteMode = ui.ariaLenient(.creditNoteMode)
            salesContactEmail = ui.ariaLenient(.salesContactEmail)
            projectionWindowDays = ui.ariaWhole(.projectionWindowDays)
        }
        if let billing = try? c.nestedContainer(keyedBy: BillingKeys.self, forKey: .billing) {
            customerVisibility = billing.ariaLenient(.customerVisibility) ?? false
        }
        trial = c.ariaLenient(.trial)
        if let overage = try? c.nestedContainer(keyedBy: OverageKeys.self, forKey: .overage) {
            atSpendCap = overage.ariaLenient(.atSpendCap)
            pricePerCredit = overage.ariaDecimal(.pricePerCredit)
            spendCapDefaultEur = overage.ariaDecimal(.spendCapDefaultEur)
        }
        if let notifications = try? c.nestedContainer(keyedBy: NotificationsKeys.self, forKey: .notifications) {
            emailNotificationsEnabled = notifications.ariaLenient(.emailEnabled) ?? false
        }
        tiers = AriaUsageTier.readList(c, .tiers)
    }

    /// Il controllo dell'impegno nella chat esiste solo se il server lista `chat.reply`.
    var chatEffortEnabled: Bool { effort?.enabledActions.contains("chat.reply") == true }

    /// I livelli presenti, dal più basso al più alto.
    var orderedLevels: [(level: AriaEffortLevel, info: Level)] {
        AriaEffortLevel.allCases.compactMap { level in
            effort?.levels[level].map { (level: level, info: $0) }
        }
    }

    var isOnTrial: Bool { trial != nil }

    /// La nota sotto la risposta si mostra salvo `ui.credit_note_mode == "off"`.
    var showsCreditNote: Bool { creditNoteMode != "off" }
}
