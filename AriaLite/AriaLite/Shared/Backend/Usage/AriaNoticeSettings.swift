//
//  AriaNoticeSettings.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  GET /v1/usage/notice-settings: le regole dei tre avvisi d'uso (crediti del giorno, tetto che si avvicina, crediti
//  extra), sei impostazioni ciascuno, ognuna `{platform, company, resolved}`. `resolved` è quella in vigore; `company`
//  `null` segue la piattaforma. Lettura tollerante: un campo illeggibile vale `nil`. Le modifiche sono in
//  `AriaNoticeOverrides`.
//

import Foundation

/// I tre avvisi, nell'ordine in cui li incontra il cliente. Il nome è la chiave del JSON.
nonisolated enum AriaNoticeKey: String, CodingKey, CaseIterable, Sendable, Hashable {
    case dailyAllowance = "daily_allowance"
    case capApproaching = "cap_approaching"
    case overage
}

/// Le sei impostazioni di un avviso.
nonisolated enum AriaNoticeSetting: CaseIterable, Sendable, Hashable {
    case email, banner, threshold, repeatPolicy, tenantRecipients, userIds
}

/// Ogni quanto un avviso può riscattare. `nil` ("Standard") lascia il braccio normale dell'avviso.
nonisolated enum AriaNoticeRepeat: String, CaseIterable, Sendable, Hashable {
    case oncePerDay = "once_per_day"
    case oncePerWeek = "once_per_week"
    case oncePerCycle = "once_per_cycle"
}

/// Il nome di un campo nel JSON di un'impostazione.
nonisolated enum AriaNoticeFieldKey: String, CodingKey {
    case platform, company, resolved
}

/// Un'impostazione: il valore della piattaforma, quello dell'azienda (`nil` segue la piattaforma) e quello in vigore.
/// Un `nil` può anche voler dire "il server non ha mandato niente di leggibile".
nonisolated struct AriaNoticeField<Value: Sendable & Equatable>: Sendable, Equatable {
    var platform: Value?
    var company: Value?
    var resolved: Value?

    /// L'azienda ha un valore suo: chip "Custom" e azione "Use platform value".
    var isCustom: Bool { company != nil }

    init(platform: Value? = nil, company: Value? = nil, resolved: Value? = nil) {
        self.platform = platform
        self.company = company
        self.resolved = resolved
    }

    /// Legge il campo `key` di `parent`; `read` legge uno dei tre valori (e dà `nil` se è illeggibile).
    init<Key: CodingKey>(_ parent: KeyedDecodingContainer<Key>, _ key: Key,
                         read: (KeyedDecodingContainer<AriaNoticeFieldKey>, AriaNoticeFieldKey) -> Value?) {
        guard let c = try? parent.nestedContainer(keyedBy: AriaNoticeFieldKey.self, forKey: key) else { self.init(); return }
        self.init(platform: read(c, .platform), company: read(c, .company), resolved: read(c, .resolved))
    }
}

/// La regola di un avviso.
nonisolated struct AriaNoticeRule: Decodable, Sendable, Equatable {
    var email = AriaNoticeField<Bool>()
    var banner = AriaNoticeField<Bool>()
    /// Una quota (0..1; 1 o più per i crediti extra), come stringa decimale sul filo.
    var threshold = AriaNoticeField<Decimal>()
    var repeatPolicy = AriaNoticeField<AriaNoticeRepeat>()
    /// I ruoli avvisati (`owner`, `member`).
    var tenantRecipients = AriaNoticeField<[String]>()
    /// Persone nominate al posto dei ruoli, per questo avviso soltanto; la piattaforma non ne nomina nessuna.
    var userIds = AriaNoticeField<[String]>()

    private enum CodingKeys: String, CodingKey {
        case email, banner, threshold
        case repeatPolicy = "repeat", tenantRecipients = "tenant_recipients", userIds = "user_ids"
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        email = AriaNoticeField(c, .email) { $0.ariaLenient(Bool.self, $1) }
        banner = AriaNoticeField(c, .banner) { $0.ariaLenient(Bool.self, $1) }
        threshold = AriaNoticeField(c, .threshold) { $0.ariaDecimal($1) }
        repeatPolicy = AriaNoticeField(c, .repeatPolicy) {
            $0.ariaLenient(String.self, $1).flatMap(AriaNoticeRepeat.init(rawValue:))
        }
        tenantRecipients = AriaNoticeField(c, .tenantRecipients) { $0.ariaLenient([String].self, $1) }
        userIds = AriaNoticeField(c, .userIds) { $0.ariaLenient([String].self, $1) }
    }

    /// I valori che l'azienda tiene come suoi.
    var companyOverride: AriaNoticeOverride {
        AriaNoticeOverride(email: email.company, banner: banner.company, threshold: threshold.company,
                           repeatPolicy: repeatPolicy.company, tenantRecipients: tenantRecipients.company,
                           userIds: userIds.company)
    }
}

nonisolated struct AriaNoticeSettings: Decodable, Sendable, Equatable {
    var dailyAllowance = AriaNoticeRule()
    var capApproaching = AriaNoticeRule()
    var overage = AriaNoticeRule()

    private enum CodingKeys: String, CodingKey {
        case dailyAllowance = "daily_allowance", capApproaching = "cap_approaching", overage
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyAllowance = c.ariaLenient(.dailyAllowance) ?? AriaNoticeRule()
        capApproaching = c.ariaLenient(.capApproaching) ?? AriaNoticeRule()
        overage = c.ariaLenient(.overage) ?? AriaNoticeRule()
    }

    subscript(notice: AriaNoticeKey) -> AriaNoticeRule {
        switch notice {
        case .dailyAllowance: dailyAllowance
        case .capApproaching: capApproaching
        case .overage: overage
        }
    }
}
