//
//  AriaNoticeOverrides.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il body di PUT /v1/usage/notice-settings. Il salvataggio SOSTITUISCE tutto: vanno mandati, ogni volta e per tutti e
//  tre gli avvisi, i valori che l'azienda tiene come suoi; un valore omesso (o `null`) torna a quello della
//  piattaforma e un avviso omesso torna intero. Mandarne uno solo cancellerebbe gli altri due. Per questo
//  `AriaNoticeSettings.payload(applying:to:)` costruisce il body completo da una vista più UNA modifica, e un valore
//  uguale a quello della piattaforma non si manda (così le modifiche future della piattaforma arrivano all'azienda).
//

import Foundation

/// Le sostituzioni di un avviso. Un valore `nil` è assente dal body.
nonisolated struct AriaNoticeOverride: Encodable, Sendable, Equatable {
    var email: Bool?
    var banner: Bool?
    /// Una quota, scritta come stringa decimale ("0.6", "0.625", "1").
    var threshold: Decimal?
    var repeatPolicy: AriaNoticeRepeat?
    var tenantRecipients: [String]?
    var userIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case email, banner, threshold
        case repeatPolicy = "repeat", tenantRecipients = "tenant_recipients", userIds = "user_ids"
    }

    init(email: Bool? = nil, banner: Bool? = nil, threshold: Decimal? = nil, repeatPolicy: AriaNoticeRepeat? = nil,
         tenantRecipients: [String]? = nil, userIds: [String]? = nil) {
        self.email = email
        self.banner = banner
        self.threshold = threshold
        self.repeatPolicy = repeatPolicy
        self.tenantRecipients = tenantRecipients
        self.userIds = userIds
    }

    var isEmpty: Bool { self == AriaNoticeOverride() }

    /// Solo le chiavi con un valore: quelle assenti seguono la piattaforma.
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(banner, forKey: .banner)
        try c.encodeIfPresent(threshold.map(AriaDecimal.wire), forKey: .threshold)
        try c.encodeIfPresent(repeatPolicy?.rawValue, forKey: .repeatPolicy)
        try c.encodeIfPresent(tenantRecipients, forKey: .tenantRecipients)
        try c.encodeIfPresent(userIds, forKey: .userIds)
    }

    /// La stessa sostituzione senza una impostazione: torna al valore della piattaforma.
    func clearing(_ setting: AriaNoticeSetting) -> AriaNoticeOverride {
        var copy = self
        switch setting {
        case .email: copy.email = nil
        case .banner: copy.banner = nil
        case .threshold: copy.threshold = nil
        case .repeatPolicy: copy.repeatPolicy = nil
        case .tenantRecipients: copy.tenantRecipients = nil
        case .userIds: copy.userIds = nil
        }
        return copy
    }
}

/// Il body completo: le sostituzioni dei tre avvisi. Un avviso senza sostituzioni non si scrive; `{}` toglie tutto.
nonisolated struct AriaNoticeOverrides: Encodable, Sendable, Equatable {
    private(set) var notices: [AriaNoticeKey: AriaNoticeOverride] = [:]

    init(notices: [AriaNoticeKey: AriaNoticeOverride] = [:]) {
        self.notices = notices.filter { !$0.value.isEmpty }
    }

    /// Le sostituzioni di un avviso (vuote se non ce ne sono). Scrivere una vuota toglie l'avviso dal body.
    subscript(notice: AriaNoticeKey) -> AriaNoticeOverride {
        get { notices[notice] ?? AriaNoticeOverride() }
        set { notices[notice] = newValue.isEmpty ? nil : newValue }
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: AriaNoticeKey.self)
        for key in AriaNoticeKey.allCases {
            if let override = notices[key] { try c.encode(override, forKey: key) }
        }
    }
}

/// Una modifica dell'utente a un'impostazione di un avviso.
nonisolated enum AriaNoticeEdit: Sendable, Equatable {
    case email(Bool)
    case banner(Bool)
    /// Una quota (0.6 = 60%).
    case threshold(Decimal)
    case repeatPolicy(AriaNoticeRepeat)
    case tenantRecipients([String])
    /// Persone nominate al posto dei ruoli; una lista vuota toglie le persone (tornano i ruoli).
    case userIds([String])
    /// "Use platform value": una sola impostazione torna a quella della piattaforma (anche "Standard" per `repeat`).
    case usePlatform(AriaNoticeSetting)
    /// "Use platform settings": tutto l'avviso torna alla piattaforma.
    case usePlatformForNotice

    /// Una soglia scritta in percentuale (60 → 0.6, 62.5 → 0.625, 100 → 1): una divisione esatta tra decimali.
    static func thresholdPercent(_ percent: Decimal) -> AriaNoticeEdit {
        .threshold(percent / 100)
    }
}

nonisolated extension AriaNoticeSettings {
    /// Quello che l'azienda tiene come suo, per tutti e tre gli avvisi.
    var companyOverrides: AriaNoticeOverrides {
        AriaNoticeOverrides(notices: Dictionary(uniqueKeysWithValues: AriaNoticeKey.allCases.map { ($0, self[$0].companyOverride) }))
    }

    /// Il body di PUT /v1/usage/notice-settings dopo UNA modifica: tutti i valori che l'azienda tiene già come suoi,
    /// per i tre avvisi, più la modifica. Un valore uguale a quello della piattaforma non si manda.
    func payload(applying edit: AriaNoticeEdit, to notice: AriaNoticeKey) -> AriaNoticeOverrides {
        var overrides = companyOverrides
        var own = overrides[notice]
        let platform = self[notice]
        switch edit {
        case .email(let value): own.email = value == platform.email.platform ? nil : value
        case .banner(let value): own.banner = value == platform.banner.platform ? nil : value
        case .threshold(let value): own.threshold = value == platform.threshold.platform ? nil : value
        case .repeatPolicy(let value): own.repeatPolicy = value == platform.repeatPolicy.platform ? nil : value
        case .tenantRecipients(let roles):
            own.tenantRecipients = Set(roles) == platform.tenantRecipients.platform.map { Set($0) } ? nil : roles
        case .userIds(let ids): own.userIds = ids.isEmpty ? nil : ids
        case .usePlatform(let setting): own = own.clearing(setting)
        case .usePlatformForNotice: own = AriaNoticeOverride()
        }
        overrides[notice] = own
        return overrides
    }
}
