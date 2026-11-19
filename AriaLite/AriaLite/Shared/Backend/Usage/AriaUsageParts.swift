//
//  AriaUsageParts.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I pezzi che il saldo (`/v1/usage/allowance`) e il cruscotto (`/v1/usage/dashboard`) hanno in comune: modo del piano,
//  stato del tetto di spesa, proiezione, archivio della conoscenza e minuti di Live Talk. Lettura tollerante: un campo
//  illeggibile vale `nil`; un valore sconosciuto di un enum vale `nil`, mai un errore.
//

import Foundation

/// `daily` (crediti giornalieri) o `pool` (un fondo mensile).
nonisolated enum AriaAllowanceMode: String, Sendable, Equatable {
    case daily, pool
}

/// Lo stato del tetto di spesa del ciclo, deciso dal server. `noLimit` è il "none" del JSON (rinominato per non
/// confonderlo con `Optional.none`).
nonisolated enum AriaSpendCapStatus: String, Sendable, Equatable {
    case noLimit = "none", ok, warned, reached
}

/// `allowance.spend_cap`: il tetto contro quanto il ciclo ha già addebitato. Solo per chi vede i soldi.
nonisolated struct AriaAllowanceSpendCap: Decodable, Sendable, Equatable {
    var state: AriaSpendCapStatus?
    /// Euro per ciclo; `nil` senza tetto.
    var amount: Decimal?
    /// Quanto il ciclo ha addebitato contro il tetto; `nil` se non si conosce (il salvataggio aspetta).
    var billed: Decimal?
    var reachedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case state, amount, billed, reachedAt = "reached_at"
    }

    init(state: AriaSpendCapStatus? = nil, amount: Decimal? = nil, billed: Decimal? = nil, reachedAt: Date? = nil) {
        self.state = state
        self.amount = amount
        self.billed = billed
        self.reachedAt = reachedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = c.ariaLenient(String.self, .state).flatMap(AriaSpendCapStatus.init(rawValue:))
        amount = c.ariaDecimal(.amount)
        billed = c.ariaDecimal(.billed)
        reachedAt = AriaDate.parse(c.ariaLenient(String.self, .reachedAt))
    }
}

/// Dove va il ciclo (solo da mostrare): `nil` su un ciclo chiuso, nel modo "day" e prima del primo giorno completo.
nonisolated struct AriaUsageProjection: Decodable, Sendable, Equatable {
    /// L'ultimo giorno del ciclo (o della prova, se finisce prima), `YYYY-MM-DD` UTC.
    var until: String?
    var daysLeft: Int?
    var windowDays: Int?
    var dailyAverage: Decimal?
    var projected: Decimal?
    var overageCredits: Decimal?
    /// `nil` per chi non vede i soldi.
    var overageAmount: Decimal?

    private enum CodingKeys: String, CodingKey {
        case until, projected
        case daysLeft = "days_left", windowDays = "window_days", dailyAverage = "daily_average"
        case overageCredits = "overage_credits", overageAmount = "overage_amount"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        until = c.ariaLenient(.until)
        daysLeft = c.ariaWhole(.daysLeft)
        windowDays = c.ariaWhole(.windowDays)
        dailyAverage = c.ariaDecimal(.dailyAverage)
        projected = c.ariaDecimal(.projected)
        overageCredits = c.ariaDecimal(.overageCredits)
        overageAmount = c.ariaDecimal(.overageAmount)
    }
}

/// `ok`, `warning`, `over_cap` o `unlimited`: lo decide il server, non si deduce dalla quota.
nonisolated enum AriaStorageState: String, Sendable, Equatable {
    case ok, warning, overCap = "over_cap", unlimited
}

/// Cosa succede oltre la capacità: un add-on fatturato o solo un avviso.
nonisolated enum AriaStorageOverCapMode: String, Sendable, Equatable {
    case billAddon = "bill_addon", allowAndNotify = "allow_and_notify"
}

nonisolated enum AriaStoragePlanKind: String, Sendable, Equatable {
    case std, pool, trial
}

/// `allowance.storage`: l'archivio della conoscenza contro la sua capacità. Un GB sono i byte diviso 1 000 000 000.
nonisolated struct AriaUsageStorage: Decodable, Sendable, Equatable {
    var usedBytes: Int?
    /// `nil` quando non c'è una capacità dichiarata (lo stato è `unlimited`).
    var includedBytes: Int?
    var addonBytes: Int?
    /// Usato ÷ incluso; `nil` senza capacità.
    var share: Decimal?
    var state: AriaStorageState?
    var mode: AriaStorageOverCapMode?
    /// Euro per GB in più al mese; `nil` in prova, senza piano e per chi non vede i soldi.
    var pricePerGbMonth: Decimal?
    var tierSource: String?
    var planKind: AriaStoragePlanKind?

    private enum CodingKeys: String, CodingKey {
        case share, state, mode
        case usedBytes = "used_bytes", includedBytes = "included_bytes", addonBytes = "addon_bytes"
        case pricePerGbMonth = "price_per_gb_month", tierSource = "tier_source", planKind = "plan_kind"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        usedBytes = c.ariaWhole(.usedBytes)
        includedBytes = c.ariaWhole(.includedBytes)
        addonBytes = c.ariaWhole(.addonBytes)
        share = c.ariaDecimal(.share)
        state = c.ariaLenient(String.self, .state).flatMap(AriaStorageState.init(rawValue:))
        mode = c.ariaLenient(String.self, .mode).flatMap(AriaStorageOverCapMode.init(rawValue:))
        pricePerGbMonth = c.ariaDecimal(.pricePerGbMonth)
        tierSource = c.ariaLenient(.tierSource)
        planKind = c.ariaLenient(String.self, .planKind).flatMap(AriaStoragePlanKind.init(rawValue:))
    }
}

/// `allowance.live_talk`: i minuti del ciclo. `nil` quando il piano non ha Live Talk o i minuti non si leggono.
nonisolated struct AriaUsageLiveTalk: Decodable, Sendable, Equatable {
    var includedMinutes: Decimal?
    var usedMinutes: Decimal?

    private enum CodingKeys: String, CodingKey {
        case includedMinutes = "included_minutes", usedMinutes = "used_minutes"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        includedMinutes = c.ariaDecimal(.includedMinutes)
        usedMinutes = c.ariaDecimal(.usedMinutes)
    }
}
