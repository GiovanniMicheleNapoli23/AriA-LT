//
//  AdminUsageStorageTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le schede "Knowledge storage" e "Talk with Aria" (contratto 3.8) e la scheda del tetto di un membro (3.9): stati,
//  frasi per piano e per chi legge, azioni di vendita, ciclo chiuso.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Usage storage card")
struct AdminUsageStorageTests {
    private func storage(_ changes: [String: Any] = [:]) -> [String: Any] {
        var base: [String: Any] = ["used_bytes": 2_100_000_000, "included_bytes": 5_000_000_000, "addon_bytes": 0, "share": "0.42",
                                   "state": "ok", "mode": "bill_addon", "price_per_gb_month": "4.8", "tier_source": "assignment",
                                   "plan_kind": "std"]
        base.merge(changes) { _, new in new }
        return base
    }

    private func card(_ changes: [String: Any] = [:], config: AriaUsageConfig? = nil,
                      board: AriaUsageDashboard? = nil) throws -> AdminUsageStorageCard {
        let allowance = try Fx.adminAllowance(top: ["storage": storage(changes)])
        let facts = try Fx.adminFacts(dashboard: board, config: config, allowance: allowance)
        let value = try #require(allowance.storage)
        return try #require(AdminUsageStorageBuilder.card(facts, value))
    }

    private func member(_ changes: [String: Any] = [:]) throws -> AdminUsageStorageCard {
        try card(changes, config: Fx.memberAdminConfig(), board: Fx.memberDashboard())
    }

    // MARK: Stati

    @Test func theStatesFollowTheAllowance() throws {
        let facts = try Fx.adminFacts()
        let read = try Fx.adminAllowance(top: ["storage": storage()])
        let noStorage = try Fx.adminAllowance(top: ["storage": NSNull()])

        #expect(AdminUsageStorageBuilder.state(facts, allowance: nil, phase: .loading) == .loading)
        #expect(AdminUsageStorageBuilder.state(facts, allowance: nil, phase: .idle) == .loading)
        #expect(AdminUsageStorageBuilder.state(facts, allowance: nil, phase: .failed) == .failed)
        // Letto ma senza `storage`: "could not load" e Riprova.
        #expect(AdminUsageStorageBuilder.state(facts, allowance: noStorage, phase: .loaded) == .failed)
        guard case .ready = AdminUsageStorageBuilder.state(facts, allowance: read, phase: .loaded) else {
            Issue.record("expected the card")
            return
        }
    }

    @Test func unreadableUsedBytesAreNotInventedAsZero() throws {
        let facts = try Fx.adminFacts()
        let broken = try Fx.adminAllowance(top: ["storage": storage(["used_bytes": "lots"])])

        #expect(AdminUsageStorageBuilder.state(facts, allowance: broken, phase: .loaded) == .failed)
    }

    // MARK: Scheda

    @Test func anHealthyCardIsGigabytesWithOneDecimal() throws {
        let c = try card()

        #expect(c.title == "Knowledge storage")
        #expect(c.used == "2.1 GB")
        #expect(c.ofText == "of 5 GB")
        #expect(c.hasCapacity)
        #expect(c.tone == .normal)
        #expect(c.percentText == "42% used")
        #expect(c.leftText == "2.9 GB left")
        #expect(abs(c.fillFraction - 0.42) < 1e-9)
        #expect(c.overFraction == 0)
        #expect(c.badge == nil)
        #expect(c.notice == nil)
        #expect(c.asOfToday == nil)
        #expect(c.addonText == nil)
    }

    @Test func theCardUsesTheServersShareAndOnlyFallsBackToTheBytes() throws {
        let server = try card(["share": "0.5"])
        let bytes = try card(["share": NSNull()])

        #expect(server.percentText == "50% used")
        #expect(bytes.percentText == "42% used")
    }

    @Test func anEmptyStoreAndAddedStorage() throws {
        let empty = try card(["used_bytes": 0, "share": "0"])
        let addon = try card(["addon_bytes": 1_000_000_000])

        #expect(empty.leftText == "Nothing uploaded yet")
        #expect(addon.addonText == "Includes 1 GB of added storage")
    }

    @Test func aClosedCycleSaysTheFigureIsAsOfToday() throws {
        let closed = try Fx.adminDashboard(period: ["closed": true])

        #expect(try card(board: closed).asOfToday == "Uploaded files, as of today")
    }

    // MARK: Avviso e frasi

    @Test func almostFullOnABilledAddonForAnOwnerNamesThePriceAndOffersToAddStorage() throws {
        let c = try card(["used_bytes": 4_500_000_000, "state": "warning", "share": "0.9"])

        #expect(c.tone == .warning)
        #expect(c.badge == "Almost full")
        #expect(c.notice?.title == "Storage almost full")
        #expect(c.notice?.body == "You have 0.5 GB left. Past 5 GB, uploads keep working and extra storage is billed at €4.80 / GB / month.")
        #expect(c.action?.label == "Add storage · €4.80 / GB / month")
        #expect(c.action?.url.absoluteString == "mailto:sales@example.test?subject=Add%20storage%20%C2%B7%20%E2%82%AC4.80%20%2F%20GB%20%2F%20month")
    }

    @Test func overTheCapacityReadsHowManyGigabytesAndTheBilledExtra() throws {
        let c = try card(["used_bytes": 5_400_000_000, "state": "over_cap", "share": "1.08"])

        #expect(c.tone == .over)
        #expect(c.badge == "Over limit")
        #expect(c.leftText == "0.4 GB over")
        #expect(c.notice?.title == "Over your storage limit")
        #expect(c.notice?.body == "You're 0.4 GB over 5 GB. Uploads still work, and the extra is billed at €4.80 / GB / month.")
        #expect(abs(c.fillFraction - 5.0 / 5.4) < 0.0001)
        #expect(abs(c.overFraction - 0.4 / 5.4) < 0.0001)
        #expect(c.percentText == "108% used")
    }

    @Test func atExactlyTheCapacityItReadsFullWithNothingLeftNotOver() throws {
        let c = try card(["used_bytes": 5_000_000_000, "state": "over_cap", "share": "1"])

        #expect(c.tone == .warning)
        #expect(c.leftText == "0 GB left")
        #expect(c.overFraction == 0)
        #expect(c.fillFraction == 1)
    }

    @Test func theStateIsTheServersNotDerivedFromTheShare() throws {
        // 90% usato ma il server dice "ok": nessun avviso.
        let c = try card(["used_bytes": 4_500_000_000, "state": "ok", "share": "0.9"])

        #expect(c.tone == .normal)
        #expect(c.notice == nil)
    }

    @Test func aMemberReadsGigabytesAndNoPriceOrAction() throws {
        let warn = try member(["used_bytes": 4_500_000_000, "state": "warning", "price_per_gb_month": NSNull()])
        let over = try member(["used_bytes": 5_400_000_000, "state": "over_cap", "price_per_gb_month": NSNull()])

        #expect(warn.notice?.body == "You have 0.5 GB left. Ask an owner if your team needs more room.")
        #expect(over.notice?.body == "Your company is 0.4 GB over its 5 GB. Uploads still work. Ask an owner about adding storage.")
        #expect(warn.action == nil)
        #expect(warn.contractNote == nil)
    }

    @Test func anOwnerWhoseBilledAddonHasNoPriceReadsTheMembersWordsAndGetsNoAction() throws {
        let c = try card(["used_bytes": 4_500_000_000, "state": "warning", "price_per_gb_month": NSNull()])

        #expect(c.notice?.body == "You have 0.5 GB left. Ask an owner if your team needs more room.")
        #expect(c.action == nil)
    }

    @Test func theTrialNamesNoPriceAndSaysToChooseAPlan() throws {
        let owner = try card(["used_bytes": 4_500_000_000, "state": "warning", "plan_kind": "trial", "price_per_gb_month": NSNull()])
        let asMember = try member(["used_bytes": 4_500_000_000, "state": "warning", "plan_kind": "trial"])
        let over = try card(["used_bytes": 5_400_000_000, "state": "over_cap", "plan_kind": "trial", "price_per_gb_month": NSNull()])

        #expect(owner.notice?.body == "Your trial includes 5 GB and you have 0.5 GB left. Past that, uploads keep working and the owner is notified. Choose a plan to get more room.")
        #expect(owner.action?.label == "Choose a plan")
        #expect(asMember.notice?.body == "You have 0.5 GB left of the 5 GB in your trial. Uploads keep working past it. Ask an owner to change plan.")
        #expect(over.notice?.body == "You're 0.4 GB over the 5 GB in your trial. Uploads still work and the owner has been notified. Choose a plan to get more room.")
    }

    @Test func aContractSaysContactSalesWithTheCurrentPlanInTheSubject() throws {
        let owner = try card(["used_bytes": 4_500_000_000, "state": "warning", "mode": "allow_and_notify", "price_per_gb_month": NSNull()])
        let over = try member(["used_bytes": 5_400_000_000, "state": "over_cap", "mode": "allow_and_notify"])

        #expect(owner.notice?.body == "You have 0.5 GB left of the 5 GB in your contract. Contact sales to raise it.")
        #expect(owner.action?.label == "Contact sales")
        #expect(owner.action?.url.absoluteString == "mailto:sales@example.test?subject=Professional%20plan%3A%20contact%20sales")
        #expect(over.notice?.body == "Your company is 0.4 GB over the 5 GB in its contract. Uploads still work. Ask an owner to contact sales.")
    }

    @Test func noPlanAssignedNeverBillsAndHasNoAction() throws {
        let owner = try card(["used_bytes": 4_500_000_000, "state": "warning", "tier_source": "unassigned_fallback", "price_per_gb_month": NSNull()])
        let over = try card(["used_bytes": 5_400_000_000, "state": "over_cap", "tier_source": "unassigned_fallback", "price_per_gb_month": NSNull()])

        #expect(owner.notice?.body == "You have 0.5 GB left. Past 5 GB, uploads keep working, and extra storage isn't billed while no plan is assigned.")
        #expect(over.notice?.body == "You're 0.4 GB over 5 GB. Uploads still work, and the extra isn't billed while no plan is assigned.")
        #expect(owner.action == nil)
    }

    @Test func noStatedCapacityHasNoBarNoPercentAndANoteForTheOwner() throws {
        let unlimited = ["included_bytes": NSNull(), "state": "unlimited", "share": NSNull()] as [String: Any]
        let owner = try card(unlimited)
        let asMember = try member(unlimited)

        #expect(!owner.hasCapacity)
        #expect(owner.ofText == "used")
        #expect(owner.percentText == nil)
        #expect(owner.leftText == nil)
        #expect(owner.fillFraction == 0)
        #expect(owner.notice == nil)
        #expect(owner.contractNote == "Your storage is set in your contract.")
        #expect(asMember.contractNote == nil)
    }
}

@Suite("Usage live talk card")
struct AdminUsageLiveTalkTests {
    private func state(allowance: AriaAllowance?, phase: AdminUsagePhase = .loaded, config: AriaUsageConfig? = nil,
                       board: AriaUsageDashboard? = nil) throws -> AdminUsageLiveTalkState {
        let facts = try Fx.adminFacts(dashboard: board, config: config, allowance: allowance)
        return AdminUsageLiveTalkBuilder.state(facts, allowance: allowance, phase: phase)
    }

    private func ready(_ state: AdminUsageLiveTalkState) throws -> AdminUsageLiveTalkCard {
        guard case .ready(let card) = state else {
            Issue.record("expected a card, got \(state)")
            throw CancellationError()
        }
        return card
    }

    private func basicConfig(member: Bool = false) throws -> AriaUsageConfig {
        var changes: [String: Any?] = ["plan": ["tier": "basic"]]
        if member { changes.merge(["can_manage_plan": false, "amounts_visible": false]) { _, new in new } }
        return try Fx.adminConfig(replacing: changes)
    }

    @Test func aPlanWithLiveTalkShowsTheMinutesUsedOfTheCap() throws {
        let allowance = try Fx.adminAllowance(top: ["live_talk": ["included_minutes": 120, "used_minutes": "45"]])
        let card = try ready(state(allowance: allowance))

        #expect(card.kind == .open)
        #expect(card.title == "Talk with Aria")
        #expect(card.value == "45 of 120 minutes")
        #expect(card.fraction == 0.375)
        #expect(card.note == "This cycle. Past the minutes, the conversation continues as text chat.")
        #expect(card.action == nil)
    }

    @Test func theBarStopsFullPastTheCap() throws {
        let allowance = try Fx.adminAllowance(top: ["live_talk": ["included_minutes": 120, "used_minutes": "150"]])

        #expect(try ready(state(allowance: allowance)).fraction == 1)
    }

    @Test func aClosedCycleShowsADashAndNoFigure() throws {
        let allowance = try Fx.adminAllowance(top: ["live_talk": ["included_minutes": 120, "used_minutes": "45"]])
        let closed = try Fx.adminDashboard(period: ["closed": true, "start": "2026-10-01", "end": "2026-10-31"])
        let card = try ready(state(allowance: allowance, board: closed))

        #expect(card.kind == .closed)
        #expect(card.value == "—")
        #expect(card.fraction == nil)
        #expect(card.note == "Minutes used in October 2026.")
    }

    @Test func aPlanWithoutLiveTalkNamesTheLowestRankedPlanThatHasIt() throws {
        let card = try ready(state(allowance: Fx.adminAllowance(), config: basicConfig()))

        #expect(card.kind == .locked)
        #expect(card.lockedChip == "Not in your plan")
        #expect(card.note == "Included from Professional: 120 minutes a month for the company.")
        #expect(card.action?.label == "Upgrade to Professional")
        #expect(card.action?.url.absoluteString == "mailto:sales@example.test?subject=AriA%20plan%20request%3A%20Professional")
        #expect(card.memberNote == nil)
    }

    @Test func theLockedCardOnTheTrialSaysChooseAPlan() throws {
        let board = try Fx.adminDashboard(top: Fx.trialTop)
        let card = try ready(state(allowance: Fx.adminAllowance(), config: basicConfig(), board: board))

        #expect(card.action?.label == "Choose a plan")
        #expect(card.action?.url.absoluteString == "mailto:sales@example.test?subject=Choose%20a%20plan")
    }

    @Test func aMemberOfALockedPlanIsToldToAskAnOwner() throws {
        let board = try Fx.memberDashboard()
        let card = try ready(state(allowance: Fx.adminAllowance(), config: basicConfig(member: true), board: board))

        #expect(card.action == nil)
        #expect(card.memberNote == "Ask an owner to change plan.")
        #expect(card.note == "Included from Professional: 120 minutes a month for the company.")
    }

    @Test func noCardWhenNoPlanIncludesLiveTalk() throws {
        let tiers: [String: Any] = ["basic": ["key": "basic", "rank": 1, "live_talk": false], "pro": ["key": "pro", "rank": 2, "live_talk": false]]
        let config = try Fx.adminConfig(replacing: ["plan": ["tier": "basic"], "tiers": tiers])

        #expect(try state(allowance: Fx.adminAllowance(), config: config) == .hidden)
    }

    @Test func noCardWhenThePlanHasLiveTalkButTheMinutesCouldNotBeRead() throws {
        // Professional ha Live Talk; il saldo è letto ma `live_talk` è null.
        #expect(try state(allowance: Fx.adminAllowance(top: ["live_talk": NSNull()])) == .hidden)
        #expect(try state(allowance: nil, phase: .failed) == .hidden)
    }

    @Test func whileTheAllowanceLoadsTheCardIsAPlaceholder() throws {
        #expect(try state(allowance: nil, phase: .loading) == .loading)
    }
}

@Suite("Usage member limit card")
struct AdminUsageMemberLimitTests {
    private func card(_ cap: [String: Any]?, config: AriaUsageConfig? = nil, closed: Bool = false) throws -> AdminUsageMemberLimit? {
        var top: [String: Any?] = ["spend_cap": cap.map { $0 as Any } ?? NSNull()]
        top["state"] = "ok"
        let board = try Fx.memberDashboard(period: closed ? ["closed": true] : [:], top: top)
        let facts = try Fx.adminFacts(dashboard: board, config: config ?? Fx.memberAdminConfig())
        return AdminUsageMemberLimitBuilder.card(facts)
    }

    @Test func aMemberReadsTheLimitInEurosWithItsCreditsAndTheChip() throws {
        let limit = try #require(try card(Fx.dashboardCap("ok", percent: 0)))

        #expect(limit.title == "Spending limit")
        // Un membro legge l'importo del tetto anche senza vedere gli altri importi.
        #expect(limit.amount == "€500")
        #expect(limit.creditsEquivalent == "= 3,125 credits")
        #expect(limit.chip == "In force")
        #expect(!limit.isReached)
        #expect(limit.warnedNote == nil)
        #expect(limit.reachedNote == nil)
        #expect(limit.managedNote == "Only owners can change this limit.")
    }

    @Test func warnedSaysTheCompanyIsCloseToTheLimit() throws {
        let limit = try #require(try card(Fx.dashboardCap("warned")))

        #expect(limit.warnedNote == "Your company is close to this limit.")
        #expect(limit.chip == "In force")
    }

    @Test func reachedOnAPlanThatStopsSaysWhenUsageResumes() throws {
        let stops = try #require(try card(Fx.dashboardCap("reached")))
        let degrades = try #require(try card(
            Fx.dashboardCap("reached"), config: Fx.memberAdminConfig(replacing: ["overage": Fx.degradeOverage])))

        #expect(stops.chip == "Reached")
        #expect(stops.isReached)
        #expect(stops.reachedNote == "Until Dec 1, usage past the included credits stops. An owner can raise the limit.")
        #expect(degrades.chip == "Reached")
        #expect(degrades.reachedNote == nil)
    }

    @Test func noCardWithoutALimitAnAmountOrOnAClosedCycle() throws {
        #expect(try card(nil) == nil)
        #expect(try card(["credits_equivalent": "3125", "status": "ok"]) == nil)
        #expect(try card(Fx.dashboardCap("ok"), closed: true) == nil)
    }

    @Test func creditsAreLeftOutWhenTheServerDoesNotSendThem() throws {
        let limit = try #require(try card(["amount": "500", "status": "ok"]))

        #expect(limit.creditsEquivalent == nil)
    }

    @Test func anOwnerHasBillingControlsNotThisCard() throws {
        let board = try Fx.adminDashboard(top: ["spend_cap": Fx.dashboardCap("ok")])
        let facts = try Fx.adminFacts(dashboard: board)

        #expect(AdminUsageMemberLimitBuilder.card(facts) == nil)
        #expect(AdminUsageMemberLimitBuilder.footerNote(facts) == nil)
    }

    @Test func theFooterNoteIsForEveryMemberOnAnyCycle() throws {
        let current = try Fx.adminFacts(dashboard: Fx.memberDashboard(), config: Fx.memberAdminConfig())
        let closed = try Fx.adminFacts(dashboard: Fx.memberDashboard(period: ["closed": true]), config: Fx.memberAdminConfig())
        let note = "Amounts in EUR, the spending limit and usage notices are managed by owners."

        #expect(AdminUsageMemberLimitBuilder.footerNote(current) == note)
        #expect(AdminUsageMemberLimitBuilder.footerNote(closed) == note)
    }
}
