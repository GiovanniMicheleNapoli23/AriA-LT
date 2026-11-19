//
//  AdminUsageSpendCapAmountTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il campo "Limit per cycle (EUR)" (contratto 5.1): come si legge un importo (cifre, due decimali, punto o virgola), il
//  minimo, i crediti che compra l'importo scritto (per difetto: l'unica cifra che l'app calcola) e la conferma di "Lower limit".
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Spend cap amount")
struct AdminUsageSpendCapAmountTests {
    private func d(_ text: String) -> Decimal { Fx.d(text) }

    // MARK: Lettura

    @Test(arguments: [("500", "500"), ("12.5", "12.5"), ("12,5", "12.5"), ("0", "0"), ("1,25", "1.25"), ("  80 ", "80"), ("007", "7")])
    func readsDigitsWithADotOrACommaAndUpToTwoDecimals(text: String, expected: String) {
        #expect(AdminUsageAmountInput.parse(text) == d(expected))
    }

    @Test(arguments: ["", " ", "abc", "1.234", "1,234", "12.", ".5", "1.2.3", "1,2,3", "-5", "€500", "5e2", "1 000", "٣"])
    func rejectsAnythingThatIsNotDigitsWithUpToTwoDecimals(text: String) {
        #expect(AdminUsageAmountInput.parse(text) == nil)
    }

    @Test func belowTheMinimumIsInvalid() {
        #expect(AdminUsageSpendCapAmount.check("99", minimum: d("100")) == .invalid)
        #expect(AdminUsageSpendCapAmount.check("100", minimum: d("100")) == .valid(d("100")))
        #expect(AdminUsageSpendCapAmount.check("0", minimum: d("0")) == .valid(0))
        #expect(AdminUsageSpendCapAmount.check("0", minimum: nil) == .valid(0))
        #expect(AdminUsageSpendCapAmount.check("1.234", minimum: nil) == .invalid)
    }

    @Test func theAmountIsWrittenWithADotAndNoExtraZeros() {
        #expect(AdminUsageSpendCapAmount.fieldText(500) == "500")
        #expect(AdminUsageSpendCapAmount.fieldText(d("12.5")) == "12.5")
    }

    // MARK: Crediti che compra l'importo

    @Test func theCreditsAreTheTypedAmountOverThePriceRoundedDown() {
        #expect(AdminUsageSpendCapAmount.credits(buying: 500, at: d("0.16")) == 3125)
        // 10.5 ÷ 0.16 = 65.625: per difetto, mai 66.
        #expect(AdminUsageSpendCapAmount.credits(buying: d("10.5"), at: d("0.16")) == 65)
        // Decimale esatto: 0.3 ÷ 0.1 fa 3 e non 2.999…
        #expect(AdminUsageSpendCapAmount.credits(buying: d("0.3"), at: d("0.1")) == 3)
        #expect(AdminUsageSpendCapAmount.credits(buying: 100, at: d("0.3")) == 333)
        #expect(AdminUsageSpendCapAmount.credits(buying: 0, at: d("0.16")) == 0)
    }

    @Test func withoutAUsablePriceThereIsNoCreditsFigure() {
        #expect(AdminUsageSpendCapAmount.credits(buying: 500, at: nil) == nil)
        #expect(AdminUsageSpendCapAmount.credits(buying: 500, at: 0) == nil)
    }

    // MARK: Il campo

    @Test func noLimitIsPrefilledWithTheSuggestionAndShowsNoPreview() throws {
        let f = try Fx.limitFacts()
        let cap = try Fx.capView(["amount": NSNull(), "credits_equivalent": NSNull(), "status": "none"])
        let form = AdminUsageSpendCapFormBuilder.form(f, cap: cap, input: AdminUsageSpendCapFormInput(allowance: .loaded))

        #expect(form.label == "Limit per cycle (EUR)")
        #expect(form.text == "1200")
        #expect(form.preview == nil)
        #expect(form.help == "Suggested: your monthly plan price, €1,200. Set €0 to never pay for extra credits.")
        #expect(form.saveTitle == "Set limit")
        #expect(form.saveEnabled)
        #expect(!form.showsCancel)
    }

    @Test func aPlanWithADefaultLimitReadsTheMinimumInsteadOfTheZeroHint() throws {
        let f = try Fx.limitFacts(config: ["overage": ["price_per_credit": "0.16", "at_spend_cap": "stop", "spend_cap_default_eur": "100"]])
        let cap = try Fx.capView(["amount": NSNull(), "minimum": "100"])
        let form = AdminUsageSpendCapFormBuilder.form(f, cap: cap, input: AdminUsageSpendCapFormInput(allowance: .loaded))
        let invalid = AdminUsageSpendCapFormBuilder.form(f, cap: cap, input: AdminUsageSpendCapFormInput(invalid: true, allowance: .loaded))

        #expect(form.help == "Suggested: your monthly plan price, €1,200. Minimum €100.")
        // Con un invio non valido il minimo sta già nell'errore.
        #expect(invalid.help == "Suggested: your monthly plan price, €1,200.")
        #expect(invalid.invalidText == "Enter an amount of €100 or more.")
    }

    @Test func changingALimitShowsWhatTheTypedAmountBuys() throws {
        let f = try Fx.limitFacts()
        let cap = try Fx.capView()
        func form(_ draft: String?, invalid: Bool = false) -> AdminUsageSpendCapForm {
            AdminUsageSpendCapFormBuilder.form(f, cap: cap, input: AdminUsageSpendCapFormInput(
                draft: draft, editing: true, invalid: invalid, allowance: .loaded))
        }

        #expect(form(nil).text == "500")
        #expect(form(nil).preview == "= 3,125 credits at €0.16 per credit")
        #expect(form("10,5").preview == "= 65 credits at €0.16 per credit")
        #expect(form("abc").preview == nil)
        #expect(form("800", invalid: true).preview == nil)
        #expect(form(nil).saveTitle == "Save")
        #expect(form(nil).showsCancel)
        // Un limite in vigore non ripete il suggerimento.
        #expect(form(nil).help == "Set €0 to never pay for extra credits.")
    }

    @Test func thePreviewNeedsThePriceFromTheConfig() throws {
        let f = try Fx.limitFacts(config: ["overage": ["at_spend_cap": "stop"]])
        let form = AdminUsageSpendCapFormBuilder.form(f, cap: try Fx.capView(), input: AdminUsageSpendCapFormInput(editing: true, allowance: .loaded))

        #expect(form.preview == nil)
    }

    @Test func saveWaitsForTheAllowance() throws {
        let f = try Fx.limitFacts()
        let unread = try Fx.limitFacts(readAllowance: false)
        let cap = try Fx.capView()
        func form(_ facts: AdminUsageFacts, _ phase: AdminUsagePhase, saving: Bool = false) -> AdminUsageSpendCapForm {
            AdminUsageSpendCapFormBuilder.form(facts, cap: cap, input: AdminUsageSpendCapFormInput(editing: true, allowance: phase, saving: saving))
        }

        #expect(form(f, .loaded).saveEnabled)
        #expect(!form(unread, .loading).saveEnabled)
        #expect(form(unread, .loading).usedError == nil)
        #expect(!form(unread, .failed).saveEnabled)
        #expect(form(unread, .failed).usedError == "What this cycle has used could not be loaded, so the limit cannot be saved yet.")
        #expect(!form(f, .loaded, saving: true).saveEnabled)
        #expect(form(f, .loaded, saving: true).saveTitle == "Saving…")
    }

    @Test func theFormShowsWithNoLimitOrAfterChangeButNeverOnTheTrial() throws {
        let noLimit = try Fx.capView(["amount": NSNull()])
        let inForce = try Fx.capView()
        let trial = try Fx.capView(["amount": "0", "locked": "trial", "source": "trial"])

        #expect(AdminUsageSpendCapFormBuilder.isShown(cap: noLimit, editing: false))
        #expect(!AdminUsageSpendCapFormBuilder.isShown(cap: inForce, editing: false))
        #expect(AdminUsageSpendCapFormBuilder.isShown(cap: inForce, editing: true))
        #expect(!AdminUsageSpendCapFormBuilder.isShown(cap: trial, editing: true))
        #expect(!AdminUsageSpendCapFormBuilder.isShown(cap: trial, editing: false))
    }

    // MARK: Invio

    @Test func aBadAmountSendsNothing() throws {
        let f = try Fx.limitFacts()
        let cap = try Fx.capView(["minimum": "100"])

        #expect(AdminUsageSpendCapFormBuilder.submit("abc", f, cap: cap) == .invalid)
        #expect(AdminUsageSpendCapFormBuilder.submit("1.234", f, cap: cap) == .invalid)
        #expect(AdminUsageSpendCapFormBuilder.submit("99", f, cap: cap) == .invalid)
        #expect(AdminUsageSpendCapFormBuilder.submit("", f, cap: cap) == .invalid)
    }

    @Test func aGoodAmountWithACommaIsSavedWithADot() throws {
        let f = try Fx.limitFacts(billed: "0")
        let cap = try Fx.capView()

        #expect(AdminUsageSpendCapFormBuilder.submit("600,5", f, cap: cap) == .save(d("600.5")))
        #expect(AdminUsageSpendCapFormBuilder.submit("0", f, cap: cap) == .save(0))
    }

    @Test func loweringBelowWhatIsUsedAsksFirstWithTheStopWords() throws {
        let f = try Fx.limitFacts(billed: "410")
        let cap = try Fx.capView()
        guard case .confirm(let confirmation) = AdminUsageSpendCapFormBuilder.submit("300", f, cap: cap) else {
            Issue.record("expected a confirmation")
            return
        }

        #expect(confirmation.title == "Lower the limit below what's already used?")
        #expect(confirmation.body == "€410.00 of extra credits are already used this cycle, more than the new €300 limit. Usage past the included credits stops right away, until Dec 1.")
        #expect(confirmation.button == "Lower limit")
        #expect(confirmation.amount == 300)
    }

    @Test func loweringBelowWhatIsUsedOnAPlanThatDegradesSaysLighterModel() throws {
        let f = try Fx.limitFacts(billed: "410", degrade: true)
        let confirmation = try #require(AdminUsageSpendCapFormBuilder.confirmation(f, cap: Fx.capView(), amount: 300))

        #expect(confirmation.body == "€410.00 of extra credits are already used this cycle, more than the new €300 limit. AriA switches to a lighter model right away, until Dec 1.")
    }

    @Test func noConfirmationAtOrAboveWhatIsUsedOrWhenItIsUnknown() throws {
        let cap = try Fx.capView()
        let same = try Fx.limitFacts(billed: "410")
        let unknown = try Fx.limitFacts(billed: nil)
        let unread = try Fx.limitFacts(readAllowance: false)

        #expect(AdminUsageSpendCapFormBuilder.confirmation(same, cap: cap, amount: 410) == nil)
        #expect(AdminUsageSpendCapFormBuilder.confirmation(same, cap: cap, amount: 600) == nil)
        #expect(AdminUsageSpendCapFormBuilder.confirmation(unknown, cap: cap, amount: 1) == nil)
        #expect(AdminUsageSpendCapFormBuilder.confirmation(unread, cap: cap, amount: 1) == nil)
        #expect(AdminUsageSpendCapFormBuilder.submit("300", unread, cap: cap) == .save(300))
    }
}
