//
//  UsageDecimalTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I decimali dei crediti: lettura rigorosa ("2.4abc" non vale 2.4), stringa o numero JSON, mai un errore; l'aritmetica
//  esatta (3.2 resta 3.2) e il formato nella lingua di chi legge.
//

import Foundation
import Testing
@testable import AriaLite

@Suite("Credit decimals")
struct UsageDecimalTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    // MARK: Lettura

    @Test(arguments: ["2.4abc", "1e3", " 2", "2 ", "", "-", ".5", "5.", "1,5", "1.2.3", "--1", "0x10", "٣"])
    func malformedTextIsNotADecimal(text: String) {
        #expect(AriaDecimal.parse(text) == nil)
    }

    @Test func strictTextParsesExactly() {
        #expect(AriaDecimal.parse("0.70") == d("0.7"))
        #expect(AriaDecimal.parse("1200") == 1200)
        #expect(AriaDecimal.parse("-1") == -1)
        #expect(AriaDecimal.parse("0") == 0)
        #expect(AriaDecimal.parse("2.4") == d("2.4"))
    }

    @Test func jsonNumbersGoThroughTheirDecimalWriting() {
        #expect(AriaDecimal.parse(40) == 40)
        #expect(AriaDecimal.parse(0.035) == d("0.035"))
        #expect(AriaDecimal.parse(Double.nan) == nil)
        #expect(AriaDecimal.parse(Double.infinity) == nil)
    }

    private struct Box: Decodable {
        let value: AriaWireDecimal
    }

    private struct Fields: Decodable {
        let a: Decimal?
        let whole: Int?
        let text: String?

        enum CodingKeys: String, CodingKey { case a, whole, text }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            a = c.ariaDecimal(.a)
            whole = c.ariaWhole(.whole)
            text = c.ariaLenient(.text)
        }
    }

    @Test(arguments: [
        (#"{"value": "2.4"}"#, "2.4"), (#"{"value": 40}"#, "40"), (#"{"value": 0.035}"#, "0.035"),
        (#"{"value": "1200"}"#, "1200"), (#"{"value": 0.1}"#, "0.1"), (#"{"value": 0.7}"#, "0.7"),
        (#"{"value": 172.8}"#, "172.8"), (#"{"value": 1.1}"#, "1.1"),
    ])
    func wireDecimalReadsStringsAndNumbers(json: String, expected: String) throws {
        let box = try UsageFixture.decode(Box.self, json)
        #expect(box.value.value == d(expected))
    }

    @Test(arguments: [#"{"value": "abc"}"#, #"{"value": "2.4abc"}"#, #"{"value": true}"#, #"{"value": [1]}"#,
                      #"{"value": {"a": 1}}"#, #"{"value": ""}"#])
    func wireDecimalNeverThrowsOnGarbage(json: String) throws {
        let box = try UsageFixture.decode(Box.self, json)
        #expect(box.value.value == nil)
    }

    @Test func containerHelpersAreLenient() throws {
        let fields = try UsageFixture.decode(Fields.self, #"{"a": "x1", "whole": 3.0, "text": 5}"#)
        #expect(fields.a == nil)
        #expect(fields.whole == 3)
        #expect(fields.text == nil)

        let missing = try UsageFixture.decode(Fields.self, #"{"a": null, "whole": "7", "text": "ok"}"#)
        #expect(missing.a == nil)
        #expect(missing.whole == 7)
        #expect(missing.text == "ok")

        let fractional = try UsageFixture.decode(Fields.self, #"{"whole": 2.5}"#)
        #expect(fractional.whole == nil)
    }

    // MARK: Aritmetica

    @Test func roundingUpKeepsExactMultiplesExact() {
        // 3.2 × 1.0 ÷ 0.1 in virgola mobile fa 32.00000000000001: un ceil ingenuo addebiterebbe 3.3.
        #expect(AriaCredits.roundUp(d("3.2") * d("1.0"), to: d("0.1")) == d("3.2"))
        #expect(AriaCredits.roundUp(d("1.0") * d("2.4"), to: d("0.1")) == d("2.4"))
        #expect(AriaCredits.roundUp(d("1.1") * d("1.7"), to: d("0.1")) == d("1.9"))
        #expect(AriaCredits.roundUp(d("1.1") * d("2.4"), to: d("0.1")) == d("2.7"))
    }

    @Test func roundingUpUsesTheIncrementNotTheDecimalPlaces() {
        #expect(AriaCredits.roundUp(d("2.01"), to: d("0.5")) == d("2.5"))
        #expect(AriaCredits.roundUp(d("2.5"), to: d("0.5")) == d("2.5"))
        #expect(AriaCredits.roundUp(d("0.01"), to: d("0.1")) == d("0.1"))
        #expect(AriaCredits.roundUp(d("0"), to: d("0.1")) == 0)
    }

    @Test func aNonPositiveIncrementLeavesTheValue() {
        #expect(AriaCredits.roundUp(d("2.34"), to: 0) == d("2.34"))
    }

    @Test func repliesPerDayRoundDownExactly() {
        #expect(AriaCredits.repliesPerDay(creditsPerDay: d("40"), cost: d("2.4")) == 16)
        #expect(AriaCredits.repliesPerDay(creditsPerDay: d("172.8"), cost: d("2.4")) == 72)
        // 0.3 ÷ 0.1 è esattamente 3 in decimale (in virgola mobile 2.9999999999999996).
        #expect(AriaCredits.repliesPerDay(creditsPerDay: d("0.3"), cost: d("0.1")) == 3)
    }

    @Test func repliesPerDayNeedBothFiguresPositive() {
        #expect(AriaCredits.repliesPerDay(creditsPerDay: nil, cost: d("2.4")) == nil)
        #expect(AriaCredits.repliesPerDay(creditsPerDay: d("40"), cost: nil) == nil)
        #expect(AriaCredits.repliesPerDay(creditsPerDay: d("40"), cost: 0) == nil)
        #expect(AriaCredits.repliesPerDay(creditsPerDay: d("40"), cost: d("-1")) == nil)
        #expect(AriaCredits.repliesPerDay(creditsPerDay: 0, cost: d("2.4")) == nil)
    }

    @Test func floorOneDecimalNeverPromisesAFraction() {
        #expect(AriaCredits.floorOneDecimal(d("27.64")) == d("27.6"))
        #expect(AriaCredits.floorOneDecimal(d("27.6")) == d("27.6"))
        #expect(AriaCredits.floorOneDecimal(d("0.99")) == d("0.9"))
        #expect(AriaCredits.floorOneDecimal(d("1158.4")) == d("1158.4"))
        #expect(AriaCredits.floorOneDecimal(0) == 0)
    }

    @Test func percentIsAWholeNumberThatCanPassOneHundred() {
        #expect(AriaCredits.percent(d("0.035")) == 4)
        #expect(AriaCredits.percent(d("0.7")) == 70)
        #expect(AriaCredits.percent(d("1.2")) == 120)
        #expect(AriaCredits.percent(0) == 0)
    }

    // MARK: Formato

    @Test func creditsFormatInTheReadersLocale() {
        let en = UsageFixture.english
        #expect(AriaCredits.format(d("1158.4"), locale: en) == "1,158.4")
        #expect(AriaCredits.format(d("2.4"), locale: en) == "2.4")
        #expect(AriaCredits.format(d("1"), locale: en) == "1")
        #expect(AriaCredits.format(d("1.0"), locale: en) == "1")
        #expect(AriaCredits.format(d("2.456"), locale: en) == "2.46")
        // L'italiano (CLDR) non raggruppa i numeri a 4 cifre, come Intl della web: "1158,4"; da 5 cifre sì.
        #expect(AriaCredits.format(d("1158.4"), locale: UsageFixture.italian) == "1158,4")
        #expect(AriaCredits.format(d("12345.6"), locale: UsageFixture.italian) == "12.345,6")
        #expect(AriaCredits.format(d("2.4"), locale: UsageFixture.italian) == "2,4")
    }

    @Test func aCreditIsSingularOnlyAtExactlyOne() {
        let en = UsageFixture.english
        #expect(AriaCredits.phrase(d("1"), locale: en) == "1 credit")
        #expect(AriaCredits.phrase(d("1.0"), locale: en) == "1 credit")
        #expect(AriaCredits.phrase(d("2.4"), locale: en) == "2.4 credits")
        #expect(AriaCredits.phrase(0, locale: en) == "0 credits")
        #expect(AriaCredits.phrase(d("1.5"), locale: en) == "1.5 credits")
    }

    @Test func multiplierHasTheTimesSignAndNoSpace() {
        #expect(AriaCredits.formatMultiplier(d("1.7"), locale: UsageFixture.english) == "1.7×")
        #expect(AriaCredits.formatMultiplier(d("1.0"), locale: UsageFixture.english) == "1×")
        #expect(AriaCredits.formatMultiplier(d("2.4"), locale: UsageFixture.italian) == "2,4×")
    }

    @Test func moneyDropsCentsOnlyForWholeAmounts() {
        let en = UsageFixture.english
        #expect(AriaCredits.formatMoney(d("269"), currency: "EUR", locale: en) == "€269")
        #expect(AriaCredits.formatMoney(d("4.8"), currency: "EUR", locale: en) == "€4.80")
        #expect(AriaCredits.formatMoney(d("0.16"), currency: "EUR", locale: en) == "€0.16")
        #expect(AriaCredits.formatMoney(d("0.1234"), currency: "EUR", locale: en) == "€0.1234")
    }
}
