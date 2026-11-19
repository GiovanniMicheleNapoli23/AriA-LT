//
//  AriaPriceList.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il listino pubblico che la card del piano mostra: GET /v1/public/price-list, senza accesso e senza Company-Id.
//  Tre risposte: un listino pubblicato, `{"published": false}` (nessun listino in vigore, oggi in prod) e un errore
//  di rete o di decodifica. Qui restano solo i campi che la card usa, con le chiavi snake_case del contratto.
//

import Foundation

/// Un importo del listino: arriva come stringa decimale esatta ("99", "0.10") o come numero (99). Mai un errore:
/// un importo illeggibile è `nil` e la card non disegna quella cifra.
nonisolated enum AriaPriceListWire {
    static func amount<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> Decimal? {
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Decimal(string: text.trimmingCharacters(in: .whitespaces), locale: Locale(identifier: "en_US_POSIX"))
        }
        return try? container.decodeIfPresent(Decimal.self, forKey: key)
    }

    /// Un campo con il tipo sbagliato o assente vale `nil`, non rompe tutto il listino.
    static func value<T: Decodable, K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> T? {
        try? container.decodeIfPresent(T.self, forKey: key)
    }
}

/// Un piano del listino (`tiers[]`), con i soli campi della card. `price` e `floorEur` sono `nil` sui piani a contratto.
nonisolated struct AriaPublicTier: Sendable, Equatable {
    let key: String
    let price: Decimal?
    let priceBasis: String?
    let includedUsers: Int?
    let creditsPerDay: Int?
    let kbCapacityGb: Double?
    let mobileOperatorsIncluded: Int?
    let maxParallelTasks: Int?
    let floorEur: Decimal?

    init(key: String, price: Decimal? = nil, priceBasis: String? = nil, includedUsers: Int? = nil,
         creditsPerDay: Int? = nil, kbCapacityGb: Double? = nil, mobileOperatorsIncluded: Int? = nil,
         maxParallelTasks: Int? = nil, floorEur: Decimal? = nil) {
        self.key = key
        self.price = price
        self.priceBasis = priceBasis
        self.includedUsers = includedUsers
        self.creditsPerDay = creditsPerDay
        self.kbCapacityGb = kbCapacityGb
        self.mobileOperatorsIncluded = mobileOperatorsIncluded
        self.maxParallelTasks = maxParallelTasks
        self.floorEur = floorEur
    }
}

nonisolated extension AriaPublicTier: Decodable {
    private enum CodingKeys: String, CodingKey {
        case key, price
        case priceBasis = "price_basis"
        case includedUsers = "included_users"
        case creditsPerDay = "credits_per_day"
        case kbCapacityGb = "kb_capacity_gb"
        case mobileOperatorsIncluded = "mobile_operators_included"
        case maxParallelTasks = "max_parallel_tasks"
        case floorEur = "floor_eur"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(key: try c.decode(String.self, forKey: .key),
                  price: AriaPriceListWire.amount(c, .price),
                  priceBasis: AriaPriceListWire.value(c, .priceBasis),
                  includedUsers: AriaPriceListWire.value(c, .includedUsers),
                  creditsPerDay: AriaPriceListWire.value(c, .creditsPerDay),
                  kbCapacityGb: AriaPriceListWire.value(c, .kbCapacityGb),
                  mobileOperatorsIncluded: AriaPriceListWire.value(c, .mobileOperatorsIncluded),
                  maxParallelTasks: AriaPriceListWire.value(c, .maxParallelTasks),
                  floorEur: AriaPriceListWire.amount(c, .floorEur))
    }
}

/// Il modello della prova (`trial`): durata, piano su cui gira e i tre limiti. `overageSpendCapEur == 0` vuol dire
/// che i crediti extra non si addebitano mai.
nonisolated struct AriaPublicTrial: Sendable, Equatable {
    let days: Int
    let tier: String
    let contractPrice: Decimal?
    let userCap: Int
    let kbCapacityGb: Double?
    let overageSpendCapEur: Decimal?
    let creditsPerDay: Int?

    init(days: Int, tier: String, contractPrice: Decimal? = nil, userCap: Int, kbCapacityGb: Double? = nil,
         overageSpendCapEur: Decimal? = nil, creditsPerDay: Int? = nil) {
        self.days = days
        self.tier = tier
        self.contractPrice = contractPrice
        self.userCap = userCap
        self.kbCapacityGb = kbCapacityGb
        self.overageSpendCapEur = overageSpendCapEur
        self.creditsPerDay = creditsPerDay
    }
}

nonisolated extension AriaPublicTrial: Decodable {
    private enum CodingKeys: String, CodingKey {
        case days, tier
        case contractPrice = "contract_price"
        case userCap = "user_cap"
        case kbCapacityGb = "kb_capacity_gb"
        case overageSpendCapEur = "overage_spend_cap_eur"
        case creditsPerDay = "credits_per_day"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(days: try c.decode(Int.self, forKey: .days),
                  tier: try c.decode(String.self, forKey: .tier),
                  contractPrice: AriaPriceListWire.amount(c, .contractPrice),
                  userCap: try c.decode(Int.self, forKey: .userCap),
                  kbCapacityGb: AriaPriceListWire.value(c, .kbCapacityGb),
                  overageSpendCapEur: AriaPriceListWire.amount(c, .overageSpendCapEur),
                  creditsPerDay: AriaPriceListWire.value(c, .creditsPerDay))
    }
}

/// La risposta di GET /v1/public/price-list. `published: false` porta solo `salesContactEmail`. Un listino pubblicato
/// senza `tiers` non è il contratto: la decodifica fallisce e la card lo tratta come non disponibile. Un `trial`
/// illeggibile vale `nil`: la card ripiega sulle sue righe di sempre.
nonisolated struct AriaPublicPriceList: Sendable, Equatable {
    let published: Bool
    let currency: String?
    let tiers: [AriaPublicTier]
    let trial: AriaPublicTrial?
    let salesContactEmail: String?

    init(published: Bool, currency: String? = nil, tiers: [AriaPublicTier] = [], trial: AriaPublicTrial? = nil,
         salesContactEmail: String? = nil) {
        self.published = published
        self.currency = currency
        self.tiers = tiers
        self.trial = trial
        self.salesContactEmail = salesContactEmail
    }

    func tier(_ key: String) -> AriaPublicTier? { tiers.first { $0.key == key } }
}

nonisolated extension AriaPublicPriceList: Decodable {
    private enum CodingKeys: String, CodingKey {
        case published, currency, tiers, trial
        case salesContactEmail = "sales_contact_email"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let published = try c.decode(Bool.self, forKey: .published)
        let email: String? = AriaPriceListWire.value(c, .salesContactEmail)
        guard published else {
            self.init(published: false, salesContactEmail: email)
            return
        }
        self.init(published: true,
                  currency: AriaPriceListWire.value(c, .currency),
                  tiers: try c.decode([AriaPublicTier].self, forKey: .tiers),
                  trial: AriaPriceListWire.value(c, .trial),
                  salesContactEmail: email)
    }
}

/// Dove sta la card del piano. `ready` solo con un listino pubblicato. `unavailable` è sia `published: false` sia
/// un errore (rete, 5xx, listino malformato): la card disegna le sue parole e basta; `salesEmail` è l'indirizzo
/// del listino se lo ha detto, `nil` dopo un errore.
nonisolated enum AriaPriceListState: Sendable, Equatable {
    case loading
    case ready(AriaPublicPriceList)
    case unavailable(salesEmail: String?)

    /// Una risposta del server: pubblicata → `ready`, altrimenti `unavailable` con l'email delle vendite.
    init(_ list: AriaPublicPriceList) {
        self = list.published ? .ready(list) : .unavailable(salesEmail: list.salesContactEmail)
    }

    /// La chiamata è fallita o la risposta non era il contratto.
    static let failed = AriaPriceListState.unavailable(salesEmail: nil)

    var list: AriaPublicPriceList? {
        if case .ready(let list) = self { return list }
        return nil
    }

    var salesEmail: String? {
        switch self {
        case .loading: nil
        case .ready(let list): list.salesContactEmail
        case .unavailable(let email): email
        }
    }
}

nonisolated extension AriaSignUpAPI {
    /// Rotta pubblica: senza Company-Id (l'azienda può non esserci) e il bearer, se c'è, non conta.
    func priceList() async throws -> AriaPublicPriceList {
        let endpoint: AriaEndpoint<AriaPublicPriceList> = AriaEndpoint(method: "GET", path: "v1/public/price-list",
                                                                       companyScoped: false)
        return try await api.call(endpoint)
    }
}
