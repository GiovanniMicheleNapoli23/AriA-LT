//
//  TrialOfferTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il passo Piano dell'iscrizione: il listino pubblico (importi come stringa o come numero, `published: false`, listino
//  senza piani) e la card della demo gratuita (durata, cifre, righe nell'ordine della web, "mai addebitati" solo a tetto
//  0, righe di sempre senza listino, pulsante, altri piani).
//

import Foundation
import Testing
@testable import AriaLite

private enum Fixture {
    static let english = Locale(identifier: "en_US")
    static let italian = Locale(identifier: "it_IT")

    static let published = #"""
    {"published":true,"currency":"EUR","add_ons":[],"extra":"ignorato",
     "tiers":[
       {"key":"basic","ordinal":1,"price":"99","price_basis":"per_user_month","included_users":3,"credits_per_day":50,
        "kb_capacity_gb":5,"mobile_operators_included":2,"max_parallel_tasks":4,"floor_eur":null},
       {"key":"enterprise","ordinal":4,"price":null,"price_basis":"per_contract","floor_eur":"1200.00"}],
     "trial":{"days":14,"tier":"basic","contract_price":"0","user_cap":5,"kb_capacity_gb":1.5,
              "overage_spend_cap_eur":"0.00","credits_per_day":30},
     "sales_contact_email":"vendite@acme.test"}
    """#

    static func decode(_ json: String) throws -> AriaPublicPriceList {
        try JSONDecoder().decode(AriaPublicPriceList.self, from: Data(json.utf8))
    }

    static let basic = AriaPublicTier(key: "basic", price: 99, includedUsers: 3, creditsPerDay: 50, kbCapacityGb: 5,
                                      mobileOperatorsIncluded: 2, maxParallelTasks: 4)

    static func makeTrial(days: Int = 14, price: Decimal? = 0, credits: Int? = 30, gb: Double? = 1.5,
                      cap: Decimal? = 0) -> AriaPublicTrial {
        AriaPublicTrial(days: days, tier: "basic", contractPrice: price, userCap: 5, kbCapacityGb: gb,
                        overageSpendCapEur: cap, creditsPerDay: credits)
    }

    static func makeReady(_ trial: AriaPublicTrial? = makeTrial(), tiers: [AriaPublicTier] = [Fixture.basic],
                      email: String? = nil) -> AriaPriceListState {
        .ready(AriaPublicPriceList(published: true, currency: "EUR", tiers: tiers, trial: trial, salesContactEmail: email))
    }

    static func offer(_ state: AriaPriceListState, locale: Locale = english, language: String = "en") -> AriaTrialOffer {
        AriaTrialOffer(state: state, locale: locale, language: language)
    }
}

@Suite("Price list")
struct PriceListDecoding {
    @Test func aPublishedListWithStringAmountsDecodes() throws {
        let list = try Fixture.decode(Fixture.published)

        #expect(list.published)
        #expect(list.currency == "EUR")
        #expect(list.tiers.map(\.key) == ["basic", "enterprise"])
        let basic = try #require(list.tier("basic"))
        #expect(basic.price == 99)
        #expect(basic.priceBasis == "per_user_month")
        #expect(basic.includedUsers == 3)
        #expect(basic.creditsPerDay == 50)
        #expect(basic.kbCapacityGb == 5)
        #expect(basic.mobileOperatorsIncluded == 2)
        #expect(basic.maxParallelTasks == 4)
        #expect(basic.floorEur == nil)
        let enterprise = try #require(list.tier("enterprise"))
        #expect(enterprise.price == nil, "sul piano a contratto il prezzo è null")
        #expect(enterprise.floorEur == 1200)
        let trial = try #require(list.trial)
        #expect(trial.days == 14)
        #expect(trial.tier == "basic")
        #expect(trial.contractPrice == 0)
        #expect(trial.userCap == 5)
        #expect(trial.kbCapacityGb == 1.5)
        #expect(trial.overageSpendCapEur == 0)
        #expect(trial.creditsPerDay == 30)
        #expect(list.salesContactEmail == "vendite@acme.test")
    }

    @Test func amountsAsNumbersDecodeToo() throws {
        let list = try Fixture.decode(#"""
        {"published":true,"currency":"EUR","tiers":[{"key":"basic","price":99,"floor_eur":0.10}],
         "trial":{"days":7,"tier":"basic","contract_price":0,"user_cap":2,"kb_capacity_gb":1,"overage_spend_cap_eur":0}}
        """#)

        let basic = try #require(list.tier("basic"))
        #expect(basic.price == 99)
        let floor = try #require(basic.floorEur)
        #expect(abs(floor - Decimal(string: "0.10")!) < Decimal(string: "0.0001")!)
        #expect(list.trial?.contractPrice == 0)
        #expect(list.trial?.overageSpendCapEur == 0)
        #expect(list.trial?.creditsPerDay == nil, "assente: nessuna cifra")
    }

    @Test func anUnreadableAmountIsMissingNotAnError() throws {
        let list = try Fixture.decode(#"{"published":true,"tiers":[{"key":"basic","price":"n/a","floor_eur":""}]}"#)
        #expect(list.tier("basic")?.price == nil)
        #expect(list.tier("basic")?.floorEur == nil)
    }

    @Test func aListThatIsNotPublishedIsUnavailableAndKeepsTheSalesEmail() throws {
        let list = try Fixture.decode(#"{"published": false, "sales_contact_email": "sales@sinaura.com"}"#)

        #expect(!list.published)
        #expect(list.tiers.isEmpty)
        #expect(AriaPriceListState(list) == .unavailable(salesEmail: "sales@sinaura.com"))
        let published = try Fixture.decode(Fixture.published)
        #expect(AriaPriceListState(published).list != nil)
    }

    @Test func aPublishedListWithoutTiersIsMalformed() {
        #expect(throws: DecodingError.self) { try Fixture.decode(#"{"published":true,"currency":"EUR"}"#) }
        #expect(throws: DecodingError.self) { try Fixture.decode(#"{"tiers":[]}"#) }
    }

    @Test func anUnreadableTrialIsNilNotAFailure() throws {
        let list = try Fixture.decode(#"{"published":true,"tiers":[],"trial":{"days":"x"}}"#)
        #expect(list.trial == nil)
        #expect(AriaPriceListState(list).list != nil)
    }

    @Test func theStatesExposeTheSalesEmail() {
        #expect(AriaPriceListState.loading.salesEmail == nil)
        #expect(AriaPriceListState.failed.salesEmail == nil)
        #expect(Fixture.makeReady(email: "a@b.test").salesEmail == "a@b.test")
    }
}

@Suite("Trial offer")
struct TrialOfferContent {
    @Test func theTrialShowsItsLengthPriceAndFigures() {
        let offer = Fixture.offer(Fixture.makeReady())

        #expect(offer.days == 14)
        #expect(!offer.isLoading)
        #expect(offer.price == "€0")
        #expect(offer.priceUnit == String(localized: "for \(14) days"))
        #expect(offer.tagline == String(localized: "Try AriaPLT free for \(14) days"))
        #expect(offer.subtitle == "\(offer.tagline) · \(offer.noCard)")
        #expect(offer.figures.map(\.value) == ["5", "30", "1.5"])
        #expect(offer.figures.map(\.label) == [String(localized: "users"), String(localized: "AI credits every day"),
                                               String(localized: "GB knowledge base")])
        let plan = "Basic"
        #expect(offer.runsOn == String(localized: "Runs on the \(plan) plan with these limits:"))
    }

    @Test func aMissingFigureIsLeftOut() {
        let noCredits = Fixture.offer(Fixture.makeReady(Fixture.makeTrial(credits: nil)))
        #expect(noCredits.figures.map(\.value) == ["5", "1.5"])
        let noGB = Fixture.offer(Fixture.makeReady(Fixture.makeTrial(gb: nil)))
        #expect(noGB.figures.map(\.value) == ["5", "30"])
        #expect(noGB.lines.count == 8, "senza GB niente riga oltre il limite")
    }

    @Test func oneUserIsSingular() {
        let one = AriaPublicTrial(days: 7, tier: "basic", userCap: 1)
        #expect(Fixture.offer(Fixture.makeReady(one)).figures.first?.label == String(localized: "user"))
    }

    @Test func aTrialWithoutPositiveDaysHasNoLength() {
        let offer = Fixture.offer(Fixture.makeReady(Fixture.makeTrial(days: 0)))
        #expect(offer.days == nil)
        #expect(offer.tagline == String(localized: "Try AriaPLT free"))
        #expect(offer.price == "€0")
    }

    @Test func aPriceThatIsNotWholeKeepsItsDecimals() {
        let price = Decimal(string: "0.10")!
        #expect(Fixture.offer(Fixture.makeReady(Fixture.makeTrial(price: price))).price == "€0.10")
        let italian = Fixture.offer(Fixture.makeReady(Fixture.makeTrial(price: 49)), locale: Fixture.italian).price
        #expect(italian?.contains("49") == true && italian?.contains("€") == true)
        #expect(Fixture.offer(Fixture.makeReady(Fixture.makeTrial(price: nil))).price == nil)
        #expect(Fixture.offer(Fixture.makeReady(Fixture.makeTrial(price: nil))).priceUnit == nil)
    }

    @Test func theLinesFollowTheWebOrder() {
        let lines = Fixture.offer(Fixture.makeReady()).lines
        let gb = "1.5"

        #expect(lines == [
            String(localized: "Mobile app for \(2) operators"),
            String(localized: "\(4) parallel agent tasks"),
            String(localized: "Single · Vertical RAG"),
            String(localized: "Limited Work Orders"),
            String(localized: "Limited compliance"),
            String(localized: "Community support"),
            String(localized: "Past the \(gb) GB knowledge base, uploads continue and the owner is notified"),
            String(localized: "Extra credits are never billed during the trial"),
            String(localized: "Past the included credits, answers continue on a lighter model."),
        ])
    }

    @Test func noOverageLinesShowOnlyAtACapOfZero() {
        let never = String(localized: "Extra credits are never billed during the trial")
        let lighter = String(localized: "Past the included credits, answers continue on a lighter model.")
        for cap in [Decimal(0), Decimal(string: "0.00")!] {
            let lines = Fixture.offer(Fixture.makeReady(Fixture.makeTrial(cap: cap))).lines
            #expect(lines.suffix(2) == [never, lighter])
        }
        let others: [Decimal?] = [5, Decimal(string: "0.50")!, nil]
        for cap in others {
            let lines = Fixture.offer(Fixture.makeReady(Fixture.makeTrial(cap: cap))).lines
            #expect(!lines.contains(never) && !lines.contains(lighter))
        }
    }

    @Test func theTiersOwnLimitsLeadOnlyWhenTheListStatesThem() {
        let bare = AriaPublicTier(key: "basic")
        let lines = Fixture.offer(Fixture.makeReady(tiers: [bare])).lines
        #expect(lines.first == String(localized: "Single · Vertical RAG"))
        #expect(Fixture.offer(Fixture.makeReady(tiers: [])).lines.first == String(localized: "Single · Vertical RAG"))
    }

    @Test func withoutAListTheOldLinesShowAndWhileLoadingNone() {
        let old = Fixture.offer(.failed)
        #expect(old.lines.count == 7)
        #expect(old.lines.first == String(localized: "Pre-registered · 1 user"))
        #expect(old.lines.last == String(localized: "Community support"))
        #expect(old.figures.isEmpty && old.price == nil && old.runsOn == nil && old.days == nil)
        #expect(!old.isLoading)
        #expect(old.tagline == String(localized: "Try AriaPLT free"))

        let loading = Fixture.offer(.loading)
        #expect(loading.isLoading)
        #expect(loading.lines.isEmpty)
        #expect(loading.figures.isEmpty)

        #expect(Fixture.offer(Fixture.makeReady(nil)).lines == old.lines, "listino pubblicato ma senza prova")
    }

    @Test func theButtonSaysTheLengthAndWhenItIsStarting() {
        func title(_ offer: AriaTrialOffer, saving: Bool = false) -> String {
            String(localized: offer.ctaTitle(isSaving: saving))
        }
        let withDays = Fixture.offer(Fixture.makeReady())
        #expect(title(withDays) == String(localized: "Start the \(14)-day free trial"))
        #expect(title(withDays).contains("14"))

        let without = Fixture.offer(.failed)
        #expect(title(without) == String(localized: "Start the free trial"))
        #expect(!title(without).contains("14"))
        #expect(title(Fixture.offer(Fixture.makeReady(Fixture.makeTrial(days: 0)))) == title(without))

        #expect(title(withDays, saving: true) == String(localized: "Starting your trial…"))
        #expect(title(without, saving: true) == title(withDays, saving: true))
    }

    @Test func theOtherPlansComeInOrderWithTheirKind() throws {
        let rows = Fixture.offer(Fixture.makeReady(email: "vendite@acme.test")).otherPlans

        #expect(rows.map(\.id) == ["basic", "basic_plus", "professional", "enterprise", "enterprise_ar_plus"])
        #expect(rows.map(\.name) == ["Basic", "Basic Plus", "Professional", "Enterprise", "Enterprise AR+"])
        #expect(rows.prefix(3).allSatisfy { $0.kind == .soon })
        let mailto = try #require(URL(string: "mailto:vendite@acme.test"))
        #expect(rows.suffix(2).allSatisfy { $0.kind == .contact(mailto) })
        #expect(rows[1].tagline == String(localized: "Built for small to mid-size sites."))
        #expect(rows.allSatisfy { !$0.tagline.isEmpty && !$0.trailing.isEmpty && $0.accessibilityLabel.contains($0.name) })
    }

    @Test(arguments: [AriaPriceListState.loading, .failed, .unavailable(salesEmail: "  "), .unavailable(salesEmail: nil)])
    func contactFallsBackToTheDefaultSalesEmail(state: AriaPriceListState) throws {
        let rows = Fixture.offer(state).otherPlans
        let mailto = try #require(URL(string: "mailto:sales@sinaura.com"))
        #expect(rows.suffix(2).allSatisfy { $0.kind == .contact(mailto) })
    }

    @Test func anUnavailableListKeepsItsOwnSalesEmail() throws {
        let rows = Fixture.offer(.unavailable(salesEmail: "sales@acme.test")).otherPlans
        let mailto = try #require(URL(string: "mailto:sales@acme.test"))
        #expect(rows.last?.kind == .contact(mailto))
    }

    @Test(arguments: [("it", "it"), ("it-IT", "it"), ("en", "en"), ("en-GB", "en"), ("fr", "en"), ("", "en")])
    func theTermsLinkFollowsTheAppLanguage(language: String, path: String) {
        #expect(AriaTrialOffer.termsLink(language: language).absoluteString
                == "https://www.sinauragroup.com/\(path)/legal/terms-of-service")
        #expect(Fixture.offer(.failed, language: language).termsURL == AriaTrialOffer.termsLink(language: language))
    }

    @Test func aTierNameComesFromItsKey() {
        #expect(AriaTrialOffer.tierName("basic_plus") == "Basic Plus")
        #expect(AriaTrialOffer.tierName("enterprise_ar_plus") == "Enterprise AR+")
        #expect(AriaTrialOffer.tierName("starter_pack") == "Starter Pack", "una chiave nuova si legge com'è")
    }
}
