//
//  UsageAllowanceTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  GET /v1/usage/allowance: lettura tollerante e quello che il saldo dice (kind, tono, titolo, seconda riga, avvisi,
//  blocchi), stato per stato come la tabella del contratto. I giorni sono UTC e non si spostano.
//

import Foundation
import Testing
@testable import AriaLite

@Suite("Allowance decoding")
struct UsageAllowanceDecodingTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    @Test func theContractExampleDecodes() throws {
        let a = try UsageFixture.allowance()

        #expect(a.enabled)
        #expect(a.tier == "basic")
        #expect(a.tierSource == "assignment")
        #expect(a.currency == "EUR")
        #expect(!a.amountsVisible)
        #expect(a.state == .ok)
        #expect(a.window?.hours == 24)
        #expect(a.window?.dailyAllowance == 40)
        #expect(a.window?.consumed == d("12.4"))
        #expect(a.window?.available == d("27.6"))
        #expect(a.window?.nextRefillAt == AriaDate.parse("2026-11-19T08:14:02Z"))
        // `billed_users` e `per_user_credits` sono numeri JSON.
        #expect(a.window?.billedUsers == 1)
        #expect(a.window?.perUserCredits == 40)
        #expect(a.period?.mode == "cycle")
        #expect(a.period?.start == "2026-11-01")
        #expect(a.period?.end == "2026-11-30")
        #expect(a.period?.basis == "max")
        #expect(a.period?.included == 1200)
        #expect(a.period?.creditsUsed == d("9.2"))
        #expect(a.period?.tokenEquivalent == d("41.6"))
        #expect(a.period?.pct == d("0.035"))
        #expect(a.period?.overageAmount == nil)
        #expect(a.period?.extraCreditsBillable == true)
        #expect(a.period?.resetsAt == AriaDate.parse("2026-12-01T00:00:00Z"))
        #expect(a.todayCredits == d("12.4"))
        #expect(a.meters?.today?.percent == 31)
        #expect(a.meters?.today?.warnThreshold == d("0.8"))
        #expect(a.meters?.week?.warnThreshold == nil)
        #expect(a.lastDays.map(\.day) == ["2026-11-12", "2026-11-18"])
        #expect(a.lastDays.last?.credits == d("12.4"))
        #expect(a.noticeThresholds == [d("0.7"), 1])
        #expect(a.trial == nil)
        #expect(a.spendCap == nil)
    }

    @Test func aDisabledFeatureIsJustDisabled() throws {
        let a = try UsageFixture.decode(AriaAllowance.self, #"{"enabled": false, "state": null, "window": null, "period": null, "last_days": []}"#)

        #expect(!a.enabled)
        #expect(a.state == nil)
        #expect(a.window == nil)
        #expect(a.period == nil)
        #expect(a.lastDays.isEmpty)
        #expect(AriaAllowanceSummary.make(a, now: UsageFixture.now, locale: UsageFixture.english) == nil)
    }

    @Test func anUnknownStateIsNilAndBadFieldsDoNotFailThePayload() throws {
        let a = try UsageFixture.allowance(
            top: ["state": "melting", "currency": 5, "last_days": [["day": "2026-11-18", "credits": "zero"], ["credits": "1"]],
                  "notice_thresholds": ["0.7", "oops", true] as [Any]],
            period: ["included": "12a", "pct": "0.5"],
            window: ["available": "x", "next_refill_at": "yesterday"])

        #expect(a.state == nil)
        #expect(a.currency == nil)
        #expect(a.period?.included == nil)
        #expect(a.period?.pct == d("0.5"))
        #expect(a.window?.available == nil)
        #expect(a.window?.nextRefillAt == nil)
        #expect(a.window?.dailyAllowance == 40)
        // Un giorno senza `day` si scarta; un importo illeggibile resta `nil`, non 0.
        #expect(a.lastDays.count == 1)
        #expect(a.lastDays.first?.credits == nil)
        #expect(a.noticeThresholds == [d("0.7")])
    }

    @Test func theSpendCapAmountIsReadFromItsJSON() throws {
        let string = try UsageFixture.allowance(top: ["spend_cap": ["state": "ok", "amount": "400.00", "billed": "12"]])
        let number = try UsageFixture.allowance(top: ["spend_cap": ["amount": 250]])
        let none = try UsageFixture.allowance(top: ["spend_cap": ["amount": NSNull()]])

        #expect(string.spendCapAmount == 400)
        #expect(number.spendCapAmount == 250)
        #expect(none.spendCapAmount == nil)
    }

    @Test func refillIsSoonUnderAnHourAndTheNearestHourOtherwise() {
        let now = UsageFixture.now
        func refill(after minutes: Double?) -> AriaAllowanceSummary.Refill {
            AriaAllowanceSummary.refillIn(minutes.map { now.addingTimeInterval($0 * 60) }, now: now)
        }

        #expect(refill(after: nil) == .unknown)
        #expect(refill(after: 10) == .soon)
        #expect(refill(after: 59.4) == .soon)
        #expect(refill(after: -5) == .soon)
        #expect(refill(after: 60) == .hours(1))
        #expect(refill(after: 61) == .hours(1))
        #expect(refill(after: 89) == .hours(1))
        #expect(refill(after: 90) == .hours(2))
        #expect(refill(after: 600) == .hours(10))
    }
}

@Suite("Allowance summary")
struct UsageAllowanceSummaryTests {
    private let en = UsageFixture.english
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    private func summary(_ a: AriaAllowance, canManage: Bool = false, locale: Locale = UsageFixture.english) throws -> AriaAllowanceSummary {
        try #require(AriaAllowanceSummary.make(a, now: UsageFixture.now, locale: locale, canManagePlan: canManage))
    }

    // MARK: Piano giornaliero

    @Test func anOkDailyPlanShowsWhatIsAvailable() throws {
        let s = try summary(try UsageFixture.allowance())

        #expect(s.kind == .daily)
        #expect(s.tone == .normal)
        #expect(s.state == .ok)
        #expect(s.headline == "27.6 credits available")
        #expect(s.subline == "refills in 10 h")
        #expect(s.alert == nil)
        #expect(abs((s.ringFraction ?? -1) - 0.69) < 0.0001)
        #expect(!s.isTrial)
        #expect(!s.isUnassigned)
        #expect(!s.isDayMode)
        #expect(s.tickFraction == 0.7)
        #expect(s.big.value == "27.6")
        #expect(s.big.label == "credits available")
        #expect(s.big.note == "Credits return 24 hours after use. Next refill in 10 h.")
    }

    @Test func availableRoundsDownToOneDecimal() throws {
        let s = try summary(try UsageFixture.allowance(window: ["available": "27.69"]))
        #expect(s.headline == "27.6 credits available")

        let one = try summary(try UsageFixture.allowance(window: ["available": "1.04"]))
        #expect(one.headline == "1 credit available")
    }

    @Test func nothingUsedSaysSo() throws {
        let s = try summary(try UsageFixture.allowance(window: ["available": "40", "next_refill_at": NSNull()]))

        #expect(s.subline == "Nothing used in 24 h")
        #expect(s.ringFraction == 1)
        #expect(s.big.note == "You haven’t used any credits in the last 24 hours.")
    }

    @Test func theWindowLengthComesFromTheServer() throws {
        let s = try summary(try UsageFixture.allowance(window: ["hours": 12, "next_refill_at": NSNull()]))

        #expect(s.subline == "Nothing used in 12 h")
        #expect(s.window?.title == "Last 12 hours")
    }

    @Test func theLastHoursBlockAndTheCycleBlockShowEachFigureAsSent() throws {
        let s = try summary(try UsageFixture.allowance())

        #expect(s.window?.title == "Last 24 hours")
        #expect(s.window?.value == "12.4 of 40 used")
        #expect(s.window?.note == "Daily allowance 40: 1 user × 40")
        #expect(abs((s.window?.fraction ?? -1) - 0.31) < 0.0001)

        #expect(s.cycle?.title == "This cycle")
        #expect(s.cycle?.value == "41.6 of 1,200")
        #expect(s.cycle?.resets == "Resets Dec 1")
        #expect(s.cycle?.usedText == "4% used")
        #expect(s.cycle?.tick == 0.7)
        #expect(abs((s.cycle?.fraction ?? -1) - 0.035) < 0.0001)
        #expect(s.cycleUsed == d("41.6"))
        #expect(s.cycleIncluded == 1200)
        #expect(s.cyclePct == 4)
        #expect(s.cycleResets == AriaDate.parse("2026-12-01T00:00:00Z"))
    }

    @Test func longConversationsCountBySizeOnlyWhenTheSizeWasCounted() throws {
        #expect(try summary(try UsageFixture.allowance()).countsBySize)
        #expect(try summary(try UsageFixture.allowance()).cycle?.bySize == "Long conversations count by size")

        let same = try summary(try UsageFixture.allowance(period: ["token_equivalent": "9.2"]))
        #expect(!same.countsBySize)
        let credits = try summary(try UsageFixture.allowance(period: ["basis": "credits"]))
        #expect(!credits.countsBySize)
    }

    @Test func aPerUserNoteIsNotShownOnATrial() throws {
        let trial: [String: Any] = ["starts_on": "2026-11-18", "ends_on": "2026-12-02", "days_left": 14]
        let s = try summary(try UsageFixture.allowance(top: ["trial": trial]))

        #expect(s.isTrial)
        #expect(s.window?.note == nil)
        #expect(s.trialLine == "Ends Dec 2")
    }

    @Test func metersShowTheirFiguresAndTheAmberThreshold() throws {
        let s = try summary(try UsageFixture.allowance())

        #expect(s.meters.map(\.title) == ["Today", "This week"])
        #expect(s.meters.first?.value == "12.4 of 40")
        #expect(s.meters.first?.percent == 31)
        #expect(s.meters.first?.isWarning == false)
        #expect(s.meters.last?.isWarning == false)
        #expect(s.meters.first?.resets == "Resets Nov 19")
        #expect(s.meters.last?.resets == "Resets Nov 23")

        let hot = try summary(try UsageFixture.allowance(top: ["meters": ["today": ["used": "33", "included": "40", "percent": 82, "warn_threshold": "0.80"] as [String: Any]]]))
        #expect(hot.meters.count == 1)
        #expect(hot.meters.first?.isWarning == true)
    }

    @Test func theSevenDayChartHasTheDailyAllowanceAsReference() throws {
        let s = try summary(try UsageFixture.allowance())
        let history = try #require(s.history)

        #expect(history.days.map(\.day) == ["2026-11-12", "2026-11-18"])
        #expect(history.days.map(\.label) == ["Thu", "Wed"])
        #expect(abs((history.days.last?.credits ?? -1) - 12.4) < 0.0001)
        #expect(history.reference == 40)
        #expect(history.average == "avg 6 a day")
        #expect(!history.isEmpty)
    }

    // MARK: Stati

    @Test func aNoticeAddsAnAlertAndKeepsTheOkHeadline() throws {
        let s = try summary(try UsageFixture.allowance(top: ["state": "notice"], period: ["pct": "0.7"]))

        #expect(s.tone == .warning)
        #expect(s.headline == "27.6 credits available")
        #expect(s.alert == AriaAllowanceSummary.Alert(title: "70% of this cycle used",
                                                      body: "You can keep working. Beyond 100%, extra credits are used.",
                                                      severity: .warning, offersPlanChange: false))
    }

    @Test func aNoticeWithNoExtraCreditsBillableSaysLighterModel() throws {
        let s = try summary(try UsageFixture.allowance(top: ["state": "notice"], period: ["pct": "0.7", "extra_credits_billable": false]))
        #expect(s.alert?.body == "You can keep working. Beyond 100%, answers use a lighter model.")

        let unassigned = try summary(try UsageFixture.allowance(top: ["state": "notice", "tier_source": "default"],
                                                                period: ["pct": "0.7", "extra_credits_billable": false]))
        #expect(unassigned.alert?.body == "You can keep working. Beyond 100%, extra credits are used.")
    }

    @Test func pacingShowsWhatTheCycleStillHas() throws {
        let s = try summary(try UsageFixture.allowance(top: ["state": "pacing"], window: ["available": "0"]))

        #expect(s.tone == .warning)
        #expect(s.headline == "1,158.4 left this cycle")
        #expect(s.subline == "refills in 10 h")
        #expect(s.ringFraction == 0)
        #expect(s.alert?.title == "Today’s share is used")
        #expect(s.alert?.body == "Your plan still has 1,158.4 credits this cycle and nothing extra is charged. More credits return as your last 24 hours roll off.")
        #expect(s.alert?.severity == .info)
        #expect(s.big.label == "left this cycle")
    }

    @Test func anOverageForAMemberShowsCreditsNeverMoney() throws {
        let s = try summary(try UsageFixture.allowance(top: ["state": "overage"], period: ["pct": "1.01", "overage_credits": "12.4", "overage_amount": "6.20", "price_per_credit": "0.50"]))

        #expect(s.tone == .warning)
        #expect(s.headline == "Extra credits in use")
        #expect(s.subline == "12.4 over your plan")
        #expect(s.alert?.title == "You’re using extra credits")
        #expect(s.alert?.body == "12.4 credits beyond your plan this cycle. Work continues as usual.")
        #expect(s.ringFraction == 1)
        #expect(s.big.value == "12.4")
        #expect(s.big.label == "extra credits this cycle")
    }

    @Test func anOverageForAnOwnerShowsTheAmountOnlyWhenItWasSent() throws {
        let period: [String: Any] = ["pct": "1.01", "overage_credits": "12.4", "overage_amount": "6.20", "price_per_credit": "0.50"]
        let owner = try summary(try UsageFixture.allowance(top: ["state": "overage", "amounts_visible": true], period: period))

        #expect(owner.subline == "€6.20 so far")
        #expect(owner.alert?.body == "€6.20 so far, at €0.50 per extra credit. Work continues as usual.")

        // Un importo `null` si nasconde: mai "€0".
        var hidden = period
        hidden["overage_amount"] = NSNull()
        let noAmount = try summary(try UsageFixture.allowance(top: ["state": "overage", "amounts_visible": true], period: hidden))
        #expect(noAmount.subline == "12.4 over your plan")
        #expect(noAmount.alert?.body == "12.4 credits beyond your plan this cycle. Work continues as usual.")
    }

    @Test func noPlanAssignedNeverShowsMoney() throws {
        let top: [String: Any] = ["state": "overage", "amounts_visible": true, "tier_source": "default"]
        let period: [String: Any] = ["overage_credits": "3", "overage_amount": "1.50", "price_per_credit": "0.50"]

        let member = try summary(try UsageFixture.allowance(top: top, period: period))
        #expect(member.isUnassigned)
        #expect(member.subline == "3 over your plan")

        let owner = try summary(try UsageFixture.allowance(top: top, period: period), canManage: true)
        #expect(owner.subline == "3 extra, not billed")
        #expect(owner.alert?.body == "No plan is assigned yet; your company runs on Basic. Extra credits are not billed, and work continues as usual.")
    }

    @Test func cappedOnATrialSaysTheTrialCreditsAreUsedUp() throws {
        let trial: [String: Any] = ["starts_on": "2026-11-18", "ends_on": "2026-12-02", "days_left": 14]
        let top: [String: Any] = ["state": "capped", "trial": trial]

        let member = try summary(try UsageFixture.allowance(top: top, window: ["available": "0"]))
        #expect(member.tone == .capped)
        #expect(member.headline == "Free trial credits used up")
        #expect(member.subline == "Lighter model in use")
        #expect(member.ringFraction == 1)
        #expect(member.alert?.severity == .critical)
        #expect(member.alert?.body == "The free trial has no extra credits. Answers use a lighter model. Ask an owner to change plan.")
        #expect(member.alert?.offersPlanChange == false)
        #expect(member.big.value == "0")

        let owner = try summary(try UsageFixture.allowance(top: top, window: ["available": "0"]), canManage: true)
        #expect(owner.alert?.body == "The free trial has no extra credits. Answers use a lighter model until you choose a plan.")
        #expect(owner.alert?.offersPlanChange == true)
    }

    @Test func cappedAtTheSpendingLimitSaysSo() throws {
        let member = try summary(try UsageFixture.allowance(top: ["state": "capped"], period: ["overage_credits": "20"]))
        #expect(member.tone == .capped)
        #expect(member.headline == "Spending limit reached")
        #expect(member.subline == "Lighter model in use")
        #expect(member.alert?.body == "Your company’s spending limit for this cycle is reached. Answers now use a lighter model.")

        let owner = try summary(try UsageFixture.allowance(top: ["state": "capped", "amounts_visible": true, "spend_cap": ["amount": "400"]],
                                                           period: ["overage_credits": "20"]))
        #expect(owner.alert?.body == "Your limit of €400 for this cycle is reached. Answers now use a lighter model and nothing more is billed.")
    }

    // MARK: Pool, senza quota, modo "day"

    @Test func aPoolShowsWhatIsLeftAndWhenItResets() throws {
        let s = try summary(try UsageFixture.allowance(period: ["included": "1240", "consumed": "0", "credits_used": "0", "token_equivalent": "0", "pct": "0"],
                                                       noWindow: true))

        #expect(s.kind == .pool)
        #expect(s.headline == "1,240 credits in pool")
        #expect(s.subline == "resets Dec 1")
        #expect(s.ringFraction == 1)
        #expect(s.window == nil)
        #expect(s.big.label == "credits left in the pool")
    }

    @Test func noStatedAllowanceHasNoStateAtAll() throws {
        for included in [NSNull() as Any, "0" as Any] {
            let s = try summary(try UsageFixture.allowance(top: ["state": "overage"], period: ["included": included, "consumed": "9.2", "pct": NSNull()],
                                                           noWindow: true))

            #expect(s.kind == .noAllowance)
            #expect(s.state == .ok)
            #expect(s.tone == .normal)
            #expect(s.headline == "9.2 credits used")
            #expect(s.subline == "this cycle")
            #expect(s.alert == nil)
            #expect(s.ringFraction == nil)
            #expect(s.cycle == nil)
            #expect(s.cycleIncluded == nil)
            #expect(s.cyclePct == nil)
        }
    }

    @Test func dayModeCountsTheUTCDay() throws {
        let s = try summary(try UsageFixture.allowance(period: ["mode": "day", "today_included": "40", "today_consumed": "10"]))

        #expect(s.isDayMode)
        #expect(s.headline == "30 credits available")
        #expect(s.subline == "resets at 00:00 UTC")
        #expect(s.window == nil)
        #expect(s.cycle?.title == "Today (UTC)")
        #expect(s.cycle?.value == "10 of 40")
        #expect(s.cycle?.resets == "Resets at 00:00 UTC")
        #expect(s.cycle?.usedText == "25% used")
        #expect(s.cycleUsed == 10)
        #expect(s.cycleIncluded == 40)
        #expect(s.cyclePct == 25)
    }

    // MARK: Ultimi 7 giorni, prova, modo "day"

    @Test func aDayWithUnreadableCreditsIsSkippedNotDrawnAsZero() throws {
        let days: [[String: String]] = [["day": "2026-11-16", "credits": "6"], ["day": "2026-11-17", "credits": "oops"],
                                        ["day": "2026-11-18", "credits": "12"]]
        let s = try summary(try UsageFixture.allowance(top: ["last_days": days]))
        let history = try #require(s.history)

        #expect(history.days.map(\.day) == ["2026-11-16", "2026-11-18"])
        // 18 ÷ 2 giorni leggibili; con lo 0 al posto del giorno illeggibile sarebbe 6.
        #expect(history.average == "avg 9 a day")
        #expect(!history.isEmpty)

        let none = try summary(try UsageFixture.allowance(top: ["last_days": [["day": "2026-11-18", "credits": "oops"]]]))
        #expect(none.history == nil)
    }

    @Test func aTrialInsideTheCycleReplacesTheCycleTitle() throws {
        let trial: [String: Any] = ["starts_on": "2026-11-10", "ends_on": "2026-11-25", "days_left": 7]
        let s = try summary(try UsageFixture.allowance(top: ["trial": trial]))

        #expect(s.cycle?.title == "Your trial")
        #expect(s.cycle?.resets == "Ends Nov 25")
        #expect(s.trialLine == "Ends Nov 25")
    }

    @Test func dayModeNoticeCountsTheDay() throws {
        let s = try summary(try UsageFixture.allowance(top: ["state": "notice"],
                                                       period: ["mode": "day", "today_included": "40", "today_consumed": "30"]))

        #expect(s.alert?.title == "75% of today’s credits used")
        #expect(s.alert?.body == "You can keep working. Beyond 100% today, extra credits are used.")
        #expect(s.cyclePct == 75)
    }

    @Test func dayModeOverageForAnOwnerShowsTheDaysAmount() throws {
        let period: [String: Any] = ["mode": "day", "today_included": "40", "today_consumed": "50", "today_overage_credits": "10",
                                     "today_overage_amount": "5.25", "price_per_credit": "0.50"]
        let s = try summary(try UsageFixture.allowance(top: ["state": "overage", "amounts_visible": true], period: period))

        #expect(s.subline == "€5.25 today")
        #expect(s.alert?.title == "Today’s credits are used up")
        #expect(s.alert?.body == "€5.25 so far today, at €0.50 per extra credit. Work continues as usual; the included credits start again at 00:00 UTC.")
        #expect(s.big.label == "extra credits today")

        let member = try summary(try UsageFixture.allowance(top: ["state": "overage"], period: period))
        #expect(member.subline == "10 over today’s credits")
        #expect(member.alert?.body == "10 credits beyond today’s credits. Work continues as usual.")
    }

    // MARK: Cifre mancanti

    @Test func aFigureThatCannotBeReadMeansNoFigure() throws {
        let noWindowFigure = try UsageFixture.allowance(window: ["available": "x"])
        #expect(AriaAllowanceSummary.make(noWindowFigure, now: UsageFixture.now, locale: en) == nil)

        let noConsumed = try UsageFixture.allowance(period: ["consumed": "abc", "credits_used": NSNull()])
        #expect(AriaAllowanceSummary.make(noConsumed, now: UsageFixture.now, locale: en) == nil)

        // Malformato non vuol dire assente: `consumed` illeggibile non ripiega su `credits_used` (che qui si legge).
        let fallsBack = try UsageFixture.allowance(period: ["consumed": "abc"])
        #expect(AriaAllowanceSummary.make(fallsBack, now: UsageFixture.now, locale: en) == nil)
        let absent = try UsageFixture.allowance(period: ["consumed": NSNull()])
        #expect(AriaAllowanceSummary.make(absent, now: UsageFixture.now, locale: en)?.cycleUsed == d("9.2"))

        // `included` illeggibile non diventa "nessuna quota"; `null` e 0 sì.
        let badIncluded = try UsageFixture.allowance(top: ["state": "overage"], period: ["included": "12a"])
        #expect(AriaAllowanceSummary.make(badIncluded, now: UsageFixture.now, locale: en) == nil)
        let nullIncluded = try UsageFixture.allowance(period: ["included": NSNull()])
        #expect(AriaAllowanceSummary.make(nullIncluded, now: UsageFixture.now, locale: en)?.kind == .noAllowance)

        // `pct` illeggibile non diventa "0% used".
        let badPct = try UsageFixture.allowance(period: ["pct": "lots"])
        #expect(AriaAllowanceSummary.make(badPct, now: UsageFixture.now, locale: en) == nil)
        let missingPct = try UsageFixture.allowance(period: ["pct": NSNull()])
        #expect(AriaAllowanceSummary.make(missingPct, now: UsageFixture.now, locale: en) == nil)

        // Nel modo "day" le cifre del giorno, se illeggibili, non ripiegano su altro.
        let badToday = try UsageFixture.allowance(period: ["mode": "day", "today_included": "40", "today_consumed": "ten"])
        #expect(AriaAllowanceSummary.make(badToday, now: UsageFixture.now, locale: en) == nil)
        let badTodayIncluded = try UsageFixture.allowance(period: ["mode": "day", "today_included": "forty", "today_consumed": "10"])
        #expect(AriaAllowanceSummary.make(badTodayIncluded, now: UsageFixture.now, locale: en) == nil)

        let noPeriod = try UsageFixture.allowance(top: ["period": NSNull()])
        #expect(AriaAllowanceSummary.make(noPeriod, now: UsageFixture.now, locale: en) == nil)
    }

    // MARK: Giorni UTC

    @Test func utcDaysAreNeverShifted() throws {
        let s = try summary(try UsageFixture.allowance(), locale: UsageFixture.italian)

        // Il primo del mese in italiano è "1° dic"; la data UTC non cade sul 30 novembre.
        #expect(s.cycle?.resets == "Resets 1° dic")
        #expect(AriaUsageDay.short("2026-12-01", locale: en) == "Dec 1")
        #expect(AriaUsageDay.short("2026-12-01", locale: UsageFixture.italian) == "1° dic")
        #expect(AriaUsageDay.short("2026-12-15", locale: UsageFixture.italian) == "15 dic")
        #expect(AriaUsageDay.long("2026-12-01", locale: UsageFixture.italian) == "1° dicembre")
        #expect(AriaUsageDay.long("2026-12-01", locale: en) == "December 1")
        #expect(AriaUsageDay.short(AriaDate.parse("2026-12-01T00:00:00Z")!, locale: en) == "Dec 1")
        #expect(AriaUsageDay.short(AriaDate.parse("2026-11-30T23:59:59Z")!, locale: en) == "Nov 30")
    }

    @Test func aDayIsMidnightUTC() {
        #expect(AriaUsageDay.date("2026-11-18") == AriaDate.parse("2026-11-18T00:00:00Z"))
        #expect(AriaUsageDay.date("2026-11-18T00:00:00Z") == AriaDate.parse("2026-11-18T00:00:00Z"))
        #expect(AriaUsageDay.weekday("2026-11-18", locale: en) == "Wed")
    }

    @Test(arguments: ["", "2026-13-01", "2026-02-31", "2026-1-5", "26-11-18", "yesterday", "2026/11/18"])
    func anInvalidDayIsNil(text: String) {
        #expect(AriaUsageDay.date(text) == nil)
        #expect(AriaUsageDay.short(text, locale: UsageFixture.english) == nil)
    }
}
