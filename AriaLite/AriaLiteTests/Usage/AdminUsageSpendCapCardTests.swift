//
//  AdminUsageSpendCapCardTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Spending limit" del titolare (contratto 5.1): la prova, nessun limite, un limite in vigore, la riga "Used"
//  e le sue regole, le frasi di "warned" e "reached" (anche dove il piano si ferma, del giorno o del ciclo), le etichette di
//  "Change" e quando "Remove limit" c'è. Una frase che vuole una cifra non arrivata si tralascia.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Spend cap card")
struct AdminUsageSpendCapCardTests {
    private func card(_ f: AdminUsageFacts, _ cap: AriaSpendCapView?, phase: AdminUsagePhase = .loaded,
                      saveFailed: Bool = false) -> AdminUsageSpendCapCard {
        AdminUsageSpendCapBuilder.card(f, cap: cap, phase: phase, saveFailed: saveFailed)
    }

    private func inForce(_ f: AdminUsageFacts, _ cap: AriaSpendCapView) throws -> AdminUsageSpendCapCard.InForce {
        guard case .inForce(let value) = card(f, cap).content else {
            Issue.record("expected a limit in force")
            throw CancellationError()
        }
        return value
    }

    // MARK: Lettura

    @Test func whileTheLimitIsReadTheCardIsAPlaceholderAndWhenItFailsItSaysSo() throws {
        let f = try Fx.limitFacts()

        #expect(card(f, nil, phase: .loading).content == .loading)
        #expect(card(f, nil, phase: .idle).content == .loading)
        #expect(card(f, nil, phase: .failed).content == .failed("The spending limit could not be loaded. Replies are not affected."))
        #expect(card(f, nil, phase: .loading).title == "Spending limit")
    }

    @Test func theDescriptionUsesTheStopWordsOnAPlanThatStops() throws {
        let stops = card(try Fx.limitFacts(), try Fx.capView())
        let degrades = card(try Fx.limitFacts(degrade: true), try Fx.capView())

        #expect(stops.description == "A limit per cycle on extra credits, in EUR. At the limit, usage past the included credits stops and nothing more is billed.")
        #expect(degrades.description == "A limit per cycle on extra credits, in EUR. Past it, AriA answers with a lighter model and nothing more is billed.")
    }

    // MARK: Prova

    @Test func theFreeTrialIsLockedAtZeroWithOnlyChooseAPlan() throws {
        let f = try Fx.limitFacts(state: "ok", amount: "0", billed: "0", percent: nil)
        let cap = try Fx.capView(["amount": "0", "credits_equivalent": "0", "locked": "trial", "source": "trial", "can_edit": false])
        guard case .trial(let trial) = card(f, cap).content else {
            Issue.record("expected the trial card")
            return
        }

        #expect(trial.amount == "€0")
        #expect(trial.chip == "Free trial")
        #expect(trial.since == "per cycle · since Nov 3")
        #expect(trial.body == "During the free trial extra credits are never billed. You can set your own limit once your plan starts.")
        #expect(trial.choosePlan?.label == "Choose a plan")
        #expect(trial.choosePlan?.url.absoluteString == "mailto:sales@example.test?subject=Choose%20a%20plan")
        #expect(!AdminUsageSpendCapFormBuilder.isShown(cap: cap, editing: true))
    }

    @Test func aTrialWhoseCreditsAreUsedReadsTheReachedSentenceWithTheEndDate() throws {
        let f = try Fx.limitFacts(allowanceTop: ["state": "capped", "trial": ["starts_on": "2026-11-10", "ends_on": "2026-11-24", "days_left": 6]])
        let cap = try Fx.capView(["amount": "0", "source": "trial"])
        guard case .trial(let trial) = card(f, cap).content else {
            Issue.record("expected the trial card")
            return
        }

        #expect(trial.body == "The trial's included credits are used, so replies use a lighter model until the trial ends on Nov 24. Extra credits are never billed during the free trial. You can set your own limit once your plan starts.")
    }

    @Test func theTrialHasNoPlanActionWithoutASalesAddress() throws {
        let f = try Fx.limitFacts(config: ["ui": ["sales_contact_email": ""]])
        let cap = try Fx.capView(["amount": "0", "locked": "trial"])
        guard case .trial(let trial) = card(f, cap).content else {
            Issue.record("expected the trial card")
            return
        }

        #expect(trial.choosePlan == nil)
    }

    // MARK: Nessun limite

    @Test func noLimitSaysThePriceOfAnExtraCreditAndShowsTheForm() throws {
        let f = try Fx.limitFacts(state: "none", amount: nil, billed: nil)
        let cap = try Fx.capView(["amount": NSNull(), "credits_equivalent": NSNull(), "status": "none"])
        guard case .noLimit(let noLimit) = card(f, cap).content else {
            Issue.record("expected the no-limit card")
            return
        }

        #expect(noLimit.chip == "No limit")
        #expect(noLimit.body == "Extra credits are billed at €0.16 each, with no upper limit.")
    }

    @Test func noLimitDropsThePriceSentenceWithoutAPrice() throws {
        let f = try Fx.limitFacts(config: ["overage": ["at_spend_cap": "stop"]])
        guard case .noLimit(let noLimit) = card(f, try Fx.capView(["amount": NSNull()])).content else {
            Issue.record("expected the no-limit card")
            return
        }

        #expect(noLimit.body == nil)
    }

    // MARK: Limite in vigore

    @Test func aLimitInForceShowsTheFigureTheFactsAndTheUsedLine() throws {
        let f = try Fx.limitFacts(state: "ok", billed: "410", percent: 82)
        let value = try inForce(f, Fx.capView())

        #expect(value.amount == "€500")
        #expect(value.credits == "= 3,125 credits")
        #expect(value.chip == "In force")
        #expect(!value.isReached)
        #expect(value.subline == "per cycle · since Nov 3 · at €0.16 per credit")
        #expect(value.used?.text == "€410.00 of €500 used this cycle · 2,562 of 3,125 credits")
        #expect(value.used?.fill == 0.82)
        #expect(value.used?.tone == .normal)
        #expect(value.warnedNote == nil)
        #expect(value.reachedNote == nil)
        #expect(value.changeLabel == "Change")
        #expect(!value.changeIsProminent)
        #expect(value.canRemove)
        #expect(value.removeLabel == "Remove limit")
        #expect(value.saveError == nil)
    }

    @Test func theBarStopsAtFullAndFollowsTheServersShareNotOurOwn() throws {
        let over = try inForce(Fx.limitFacts(state: "reached", billed: "500", percent: 130), Fx.capView())
        let noShare = try inForce(Fx.limitFacts(billed: "410", percent: nil), Fx.capView())

        #expect(over.used?.fill == 1)
        #expect(over.used?.tone == .over)
        // Senza la quota del server la barra non si disegna; la riga "used" resta.
        #expect(noShare.used?.fill == nil)
        #expect(noShare.used?.text.hasPrefix("€410.00 of €500 used this cycle") == true)
    }

    @Test func theUsedLineIsLeftOutWhileWhatTheCycleBilledIsUnknown() throws {
        let unknown = try inForce(Fx.limitFacts(billed: nil), Fx.capView())
        let unread = try inForce(Fx.limitFacts(readAllowance: false), Fx.capView())

        #expect(unknown.used == nil)
        #expect(unread.used == nil)
    }

    @Test func theUsedLineHasNoCreditsPartWithoutTheDashboardsCredits() throws {
        let f = try Fx.limitFacts(billed: "410")
        let value = try inForce(f, Fx.capView(["credits_equivalent": NSNull()]))

        #expect(value.used?.text == "€410.00 of €500 used this cycle")
        #expect(value.credits == nil)
    }

    @Test func aZeroLimitHasNoUsedLineAndNoRemove() throws {
        let f = try Fx.limitFacts(state: "reached", amount: "0", billed: "0", degrade: true)
        let value = try inForce(f, Fx.capView(["amount": "0", "credits_equivalent": "0", "suggestion": NSNull()]))

        #expect(value.amount == "€0")
        #expect(value.used == nil)
        #expect(!value.canRemove)
        #expect(value.reachedNote == "Replies use a lighter model until Dec 1. Nothing is billed past the limit. Extra credits are never billed.")
    }

    @Test func aPlanDefaultLimitCannotBeRemovedAndSaysSo() throws {
        let f = try Fx.limitFacts(config: ["overage": ["price_per_credit": "0.16", "at_spend_cap": "stop", "spend_cap_default_eur": "500"]])
        let value = try inForce(f, Fx.capView(["origin": "default"]))

        #expect(!value.canRemove)
        #expect(value.alwaysOnNote == "This limit is always on. You can change the amount, but not remove it.")
        #expect(value.subline == "per cycle · default for your plan · at €0.16 per credit")
    }

    @Test func aSavedLimitCanBeRemovedWhenThePlanKeepsNoDefault() throws {
        let value = try inForce(Fx.limitFacts(), Fx.capView())

        #expect(value.canRemove)
        #expect(value.alwaysOnNote == nil)
    }

    @Test func theSublineDropsThePriceWhenItIsNotKnown() throws {
        let f = try Fx.limitFacts(config: ["overage": ["at_spend_cap": "stop"]])
        let value = try inForce(f, Fx.capView())

        #expect(value.subline == "per cycle · since Nov 3")
    }

    // MARK: Warned

    @Test func warnedOnAPlanThatStopsReadsTheDayWords() throws {
        let value = try inForce(Fx.limitFacts(state: "warned"), Fx.capView(["status": "warned"]))

        #expect(value.warnedNote == "82% of your limit is used. At €500, usage past each day's included credits stops.")
        #expect(value.used?.tone == .warning)
    }

    @Test func warnedOnAPoolReadsTheCycleWords() throws {
        let value = try inForce(Fx.limitFacts(state: "warned", allowanceTop: ["mode": "pool"]), Fx.capView())

        #expect(value.warnedNote == "82% of your limit is used. At €500, usage past the included credits stops.")
    }

    @Test func warnedOnAPlanThatDegradesSaysLighterModel() throws {
        let value = try inForce(Fx.limitFacts(state: "warned", degrade: true), Fx.capView())

        #expect(value.warnedNote == "82% of your limit is used. At €500, AriA switches to a lighter model.")
    }

    @Test func warnedWithoutTheServersPercentOrWithoutTheAllowanceWordsHasNoSentence() throws {
        let noPercent = try inForce(Fx.limitFacts(state: "warned", percent: nil), Fx.capView())
        // Il saldo non letto: lo stato viene dalla scheda e le parole dello stop non si sanno.
        let unread = try inForce(Fx.limitFacts(state: "warned", readAllowance: false), Fx.capView(["status": "warned"]))

        #expect(noPercent.warnedNote == nil)
        #expect(unread.warnedNote == nil)
    }

    // MARK: Reached

    @Test func reachedOnAPlanThatStopsRaisesTheLimitAndSaysUntilWhen() throws {
        let value = try inForce(Fx.limitFacts(state: "reached", billed: "500", percent: 100), Fx.capView(["status": "reached"]))

        #expect(value.chip == "Reached")
        #expect(value.isReached)
        #expect(value.changeLabel == "Raise the limit")
        #expect(value.changeIsProminent)
        #expect(value.reachedNote == "Until Dec 1, usage past each day's included credits stops. Usage within the daily credits still works. Raise the limit to resume right away.")
        #expect(value.used?.tone == .over)
    }

    @Test func reachedOnAPoolSaysTheCycleWordsAndWithoutTheAllowanceNothing() throws {
        let pool = try inForce(Fx.limitFacts(state: "reached", allowanceTop: ["mode": "pool"]), Fx.capView())
        let unread = try inForce(Fx.limitFacts(state: "reached", readAllowance: false), Fx.capView(["status": "reached"]))

        #expect(pool.reachedNote == "Until Dec 1, usage past the included credits stops. Usage within the included credits still works. Raise the limit to resume right away.")
        #expect(unread.reachedNote == nil)
        // Il bottone resta quello dello stato: "Raise the limit" dove il piano si ferma.
        #expect(unread.changeLabel == "Raise the limit")
    }

    @Test func reachedOnAPlanThatDegradesIsAPlainChangeLimit() throws {
        let value = try inForce(Fx.limitFacts(state: "reached", degrade: true), Fx.capView())

        #expect(value.changeLabel == "Change limit")
        #expect(!value.changeIsProminent)
        #expect(value.reachedNote == "Replies use a lighter model until Dec 1. Nothing is billed past the limit.")
    }

    @Test func reachedInDayModeNamesEachDaysCredits() throws {
        let f = try Fx.limitFacts(state: "reached", degrade: true,
                                  period: ["mode": "day", "today_included": "175", "today_consumed": "175"])
        let value = try inForce(f, Fx.capView())

        #expect(value.reachedNote == "Past each day's included credits, replies use a lighter model until Dec 1. Nothing is billed past the limit.")
    }

    @Test func theStateComesFromTheAllowanceBeforeTheCardsOwnStatus() throws {
        // La scheda dice "ok" ma il saldo, letto dopo, dice "reached": vale il saldo.
        let value = try inForce(Fx.limitFacts(state: "reached"), Fx.capView(["status": "ok"]))

        #expect(value.isReached)
    }

    // MARK: Salvataggio fallito

    @Test func aFailedSaveShowsTheOneSentenceOnTheCard() throws {
        let f = try Fx.limitFacts()
        guard case .inForce(let value) = card(f, try Fx.capView(), saveFailed: true).content else {
            Issue.record("expected a limit in force")
            return
        }

        #expect(value.saveError == "The limit was not saved. Try again.")
    }

    @Test func allFourRefusalsReadTheSameSentence() {
        let codes: [AriaUsageRefusal.Code] = [.spendCapLockedTrial, .spendCapLockedUnassigned, .spendCapRequired, .spendCapBelowMinimum]

        #expect(Set(codes.map { AriaUsageRefusal(code: $0).message }) == ["The limit was not saved. Try again."])
    }
}
