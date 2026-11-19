//
//  UsageAllowanceExtrasTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Quello che la sezione Usage aggiunge a config e saldo: i piani (rango, "Upgrade to {plan}", Live Talk), il prezzo
//  del credito extra, le soglie, l'archivio, i minuti di Live Talk, la proiezione e il tetto tipizzato. Un server
//  vecchio lascia tutto `nil` o `false` (sezione 8).
//

import Foundation
import Testing
@testable import AriaLite

@Suite("Usage config tiers and overage")
struct UsageConfigTiersTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    private static let tiersJSON = """
    {
      "plan": { "tier": "basic" },
      "tiers": {
        "enterprise":   { "key": "enterprise", "rank": 4, "current": false, "credit_pool_per_cycle": 3000, "credits_per_day": null,
                          "credits_scale_with_users": false, "live_talk": true, "live_talk_minutes_per_cycle": 600 },
        "professional": { "key": "professional", "rank": 3, "current": false, "included_users": 7, "credits_per_day": 25,
                          "credits_scale_with_users": true, "credit_pool_per_cycle": null, "live_talk": true,
                          "live_talk_minutes_per_cycle": 120 },
        "basic":        { "key": "basic", "rank": 1, "current": true, "included_users": 1, "credits_per_day": 40,
                          "credits_scale_with_users": true, "live_talk": false, "live_talk_minutes_per_cycle": 0 },
        "basic_plus":   { "key": "basic_plus", "rank": 2, "current": false, "credits_per_day": "100",
                          "credits_scale_with_users": false, "live_talk": false },
        "broken":       "nope"
      },
      "overage": { "price_per_credit": "0.16", "at_spend_cap": "stop", "spend_cap_default_eur": "500" },
      "ui": { "projection_window_days": 7 },
      "notifications": { "email_enabled": true }
    }
    """

    @Test func tiersComeInRankOrderWhateverTheKeyOrderAndABrokenOneIsDropped() throws {
        let config = try UsageFixture.config(Self.tiersJSON)

        #expect(config.tiers.map(\.key) == ["basic", "basic_plus", "professional", "enterprise"])
        #expect(config.tiers.map(\.rank) == [1, 2, 3, 4])
        #expect(config.ownTier?.key == "basic")
        #expect(config.ownTier?.current == true)
    }

    @Test func aTierCarriesWhatTheUpgradeAndLiveTalkNeed() throws {
        let config = try UsageFixture.config(Self.tiersJSON)
        let pro = try #require(config.tiers.first { $0.key == "professional" })
        let plus = try #require(config.tiers.first { $0.key == "basic_plus" })

        #expect(pro.creditsPerDay == 25)
        #expect(pro.creditsScaleWithUsers)
        #expect(pro.includedUsers == 7)
        #expect(pro.liveTalk)
        #expect(pro.liveTalkMinutesPerCycle == 120)
        // Un numero scritto come stringa si legge uguale; un campo mancante non è zero.
        #expect(plus.creditsPerDay == 100)
        #expect(plus.liveTalkMinutesPerCycle == nil)
        #expect(plus.includedUsers == nil)
    }

    @Test func liveTalkNamesTheLowestRankedPlanThatIncludesIt() throws {
        let config = try UsageFixture.config(Self.tiersJSON)

        #expect(config.firstLiveTalkTier?.key == "professional")
        #expect(config.firstLiveTalkTier?.liveTalkMinutesPerCycle == 120)
    }

    @Test func aTierWithoutItsOwnKeyTakesTheMapKeyAndAnArrayWorksToo() throws {
        let map = try UsageFixture.config(#"{"tiers": {"basic": {"rank": 1}, "pro": {"rank": 2, "live_talk": true}}}"#)
        let list = try UsageFixture.config(#"{"tiers": [{"key": "pro", "rank": 2}, {"key": "basic", "rank": 1}, {"rank": 9}]}"#)

        #expect(map.tiers.map(\.key) == ["basic", "pro"])
        #expect(list.tiers.map(\.key) == ["basic", "pro"])
    }

    @Test func tiersWithoutRankComeLastByKey() throws {
        let config = try UsageFixture.config(#"{"tiers": {"zeta": {}, "alpha": {}, "mid": {"rank": 2}}}"#)

        #expect(config.tiers.map(\.key) == ["mid", "alpha", "zeta"])
    }

    @Test func overageNotificationsAndProjectionWindowAreRead() throws {
        let config = try UsageFixture.config(Self.tiersJSON)

        #expect(config.pricePerCredit == d("0.16"))
        #expect(config.spendCapDefaultEur == 500)
        #expect(config.atSpendCap == "stop")
        #expect(config.projectionWindowDays == 7)
        #expect(config.emailNotificationsEnabled)
    }

    @Test func anOlderServerLeavesThemNilOrFalse() throws {
        let config = try UsageFixture.config()

        #expect(config.pricePerCredit == nil)
        #expect(config.spendCapDefaultEur == nil)
        #expect(config.projectionWindowDays == nil)
        #expect(!config.emailNotificationsEnabled)
        // `"tiers": []` del vecchio esempio non è una mappa: nessun piano, nessun errore.
        #expect(config.tiers.isEmpty)
        #expect(config.firstLiveTalkTier == nil)
        #expect(config.ownTier == nil)
        #expect(config.atSpendCap == "stop")
    }

    @Test func overagePricesAreNilNotZeroWhenHiddenOrBad() throws {
        let hidden = try UsageFixture.config(#"{"overage": {"price_per_credit": null, "spend_cap_default_eur": "x"}}"#)

        #expect(hidden.pricePerCredit == nil)
        #expect(hidden.spendCapDefaultEur == nil)
    }

    // MARK: Upgrade to {plan}

    private func period(mode: String = "cycle", included: String?, days: Int?, todayIncluded: String? = nil) throws -> AriaAllowance.Period {
        try UsageFixture.decode(AriaAllowance.Period.self, """
        {"mode": "\(mode)", "included": \(included.map { "\"\($0)\"" } ?? "null"), "included_days": \(days.map(String.init) ?? "null"),
         "today_included": \(todayIncluded.map { "\"\($0)\"" } ?? "null")}
        """)
    }

    @Test func theUpgradeTargetIsTheFirstHigherPlanThatIncludesMore() throws {
        let config = try UsageFixture.config(Self.tiersJSON)

        // Basic: 1200 ÷ 30 = 40 al giorno. Basic Plus ne include 100: è il bersaglio.
        #expect(config.upgradeTarget(period: try period(included: "1200", days: 30))?.key == "basic_plus")
    }

    @Test func aPlanThatIncludesNoMoreIsNoTarget() throws {
        var json = Self.tiersJSON
        json = json.replacingOccurrences(of: #""plan": { "tier": "basic" }"#, with: #""plan": { "tier": "professional" }"#)
        let config = try UsageFixture.config(json)

        // Professional: 5250 ÷ 30 = 175 al giorno. Enterprise, un pool di 3000 su 30 giorni, ne include 100: non è un bersaglio.
        #expect(config.upgradeTarget(period: try period(included: "5250", days: 30)) == nil)
    }

    @Test func inDayModeTheOwnQuotaIsTodaysIncluded() throws {
        let config = try UsageFixture.config(Self.tiersJSON)

        #expect(config.upgradeTarget(period: try period(mode: "day", included: nil, days: 30, todayIncluded: "150"))?.key == "professional")
    }

    @Test func withoutAPeriodOrAKnownPlanThereIsNoTarget() throws {
        let config = try UsageFixture.config(Self.tiersJSON)
        let unknown = try UsageFixture.config(#"{"plan": {"tier": "mystery"}, "tiers": {"basic": {"rank": 1}}}"#)

        #expect(config.upgradeTarget(period: nil) == nil)
        #expect(unknown.upgradeTarget(period: try period(included: "1200", days: 30)) == nil)
    }

    @Test func aPoolPlanSpreadsItsCreditsOverTheDays() {
        let pool = AriaUsageTier(key: "enterprise", rank: 4, creditPoolPerCycle: 3000)
        let perUser = AriaUsageTier(key: "pro", rank: 3, includedUsers: 7, creditsPerDay: 25, creditsScaleWithUsers: true)
        let flat = AriaUsageTier(key: "plus", rank: 2, creditsPerDay: 100)

        #expect(pool.dailyCredits(overDays: 30) == 100)
        #expect(pool.dailyCredits(overDays: nil) == nil)
        #expect(pool.dailyCredits(overDays: 0) == nil)
        #expect(perUser.dailyCredits(overDays: nil) == 175)
        #expect(flat.dailyCredits(overDays: 30) == 100)
        #expect(AriaUsageTier(key: "x").dailyCredits(overDays: 30) == nil)
    }
}

@Suite("Usage allowance extras")
struct UsageAllowanceExtrasTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    @Test func anOlderServerLeavesTheNewPartsNil() throws {
        let a = try UsageFixture.allowance()

        #expect(a.mode == .daily)
        #expect(a.storage == nil)
        #expect(a.liveTalk == nil)
        #expect(a.projection == nil)
        #expect(a.spendCap == nil)
        // Il valore di riposo: chiavi del tutto assenti, non `null`.
        let bare = try UsageFixture.decode(AriaAllowance.self, #"{"enabled": true}"#)
        #expect(bare.mode == nil)
        #expect(bare.storage == nil)
        #expect(bare.liveTalk == nil)
        #expect(bare.projection == nil)
        #expect(bare.spendCap == nil)
        #expect(bare.meters == nil)
    }

    @Test func theModeIsDailyOrPoolAndAnythingElseIsNil() throws {
        #expect(try UsageFixture.allowance(top: ["mode": "pool"]).mode == .pool)
        #expect(try UsageFixture.allowance(top: ["mode": "weekly"]).mode == nil)
    }

    @Test func storageIsRead() throws {
        let a = try UsageFixture.allowance(top: ["storage": [
            "used_bytes": 4_200_000_000, "included_bytes": 5_000_000_000, "addon_bytes": 1_000_000_000, "share": 0.84,
            "state": "warning", "mode": "bill_addon", "price_per_gb_month": "2.5", "tier_source": "assignment", "plan_kind": "std",
        ]])
        let storage = try #require(a.storage)

        #expect(storage.usedBytes == 4_200_000_000)
        #expect(storage.includedBytes == 5_000_000_000)
        #expect(storage.addonBytes == 1_000_000_000)
        #expect(storage.share == d("0.84"))
        #expect(storage.state == .warning)
        #expect(storage.mode == .billAddon)
        #expect(storage.pricePerGbMonth == d("2.5"))
        #expect(storage.tierSource == "assignment")
        #expect(storage.planKind == .std)
    }

    @Test func unlimitedStorageHasNoCapacityNoShareAndNoPrice() throws {
        let a = try UsageFixture.allowance(top: ["storage": [
            "used_bytes": 10, "included_bytes": NSNull(), "addon_bytes": 0, "share": NSNull(), "state": "unlimited",
            "mode": "allow_and_notify", "price_per_gb_month": NSNull(), "tier_source": "unassigned_fallback", "plan_kind": "trial",
        ]])
        let storage = try #require(a.storage)

        #expect(storage.includedBytes == nil)
        #expect(storage.share == nil)
        #expect(storage.state == .unlimited)
        #expect(storage.mode == .allowAndNotify)
        #expect(storage.pricePerGbMonth == nil)
        #expect(storage.planKind == .trial)
        #expect(storage.usedBytes == 10)
    }

    @Test func everyStorageStateIsRecognisedAndAnUnknownOneIsNil() throws {
        func state(_ value: String) throws -> AriaStorageState? {
            try UsageFixture.allowance(top: ["storage": ["state": value]]).storage?.state
        }

        #expect(try state("ok") == .ok)
        #expect(try state("over_cap") == .overCap)
        #expect(try state("warning") == .warning)
        #expect(try state("unlimited") == .unlimited)
        #expect(try state("on_fire") == nil)
    }

    @Test func liveTalkMinutesAreRead() throws {
        let a = try UsageFixture.allowance(top: ["live_talk": ["included_minutes": 120, "used_minutes": "37.5"]])

        #expect(a.liveTalk?.includedMinutes == 120)
        #expect(a.liveTalk?.usedMinutes == d("37.5"))
    }

    @Test func theProjectionIsRead() throws {
        let a = try UsageFixture.allowance(top: ["projection": [
            "until": "2026-11-30", "days_left": 12, "window_days": 7, "daily_average": "212.9",
            "projected": "6387.3", "overage_credits": "1137.3", "overage_amount": NSNull(),
        ]])

        #expect(a.projection?.until == "2026-11-30")
        #expect(a.projection?.daysLeft == 12)
        #expect(a.projection?.projected == d("6387.3"))
        #expect(a.projection?.overageCredits == d("1137.3"))
        // Importo nascosto: `nil`, mai 0.
        #expect(a.projection?.overageAmount == nil)
    }

    @Test func theSpendCapIsTypedAndItsAmountStillReadsThroughTheOldProperty() throws {
        let a = try UsageFixture.allowance(top: ["spend_cap": [
            "state": "warned", "amount": "400.00", "billed": "340.5", "reached_at": "2026-11-17T10:00:00",
        ]])

        #expect(a.spendCap?.state == .warned)
        #expect(a.spendCap?.amount == 400)
        #expect(a.spendCap?.billed == d("340.5"))
        #expect(a.spendCap?.reachedAt == AriaDate.parse("2026-11-17T10:00:00Z"))
        #expect(a.spendCapAmount == 400)
    }

    @Test func everySpendCapStateIsRecognisedAndAnUnknownOneIsNil() throws {
        func state(_ value: String) throws -> AriaSpendCapStatus? {
            try UsageFixture.allowance(top: ["spend_cap": ["state": value]]).spendCap?.state
        }

        #expect(try state("none") == .noLimit)
        #expect(try state("ok") == .ok)
        #expect(try state("warned") == .warned)
        #expect(try state("reached") == .reached)
        #expect(try state("exploded") == nil)
    }

    @Test func aBadSpendCapIsNilNotAFailedPayload() throws {
        let a = try UsageFixture.allowance(top: ["spend_cap": "none"])

        #expect(a.spendCap == nil)
        #expect(a.spendCapAmount == nil)
        #expect(a.enabled)
    }

    @Test func theTodayMeterKeepsItsWarnThreshold() throws {
        let a = try UsageFixture.allowance()

        #expect(a.meters?.today?.warnThreshold == d("0.8"))
        #expect(a.meters?.week?.warnThreshold == nil)
    }

    @Test func thePeriodKeepsItsDays() throws {
        let a = try UsageFixture.allowance()

        #expect(a.period?.includedDays == 30)
    }
}
