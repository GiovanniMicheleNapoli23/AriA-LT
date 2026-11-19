//
//  AdminUsageFormatTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Come la pagina Usage scrive crediti, importi, quote, byte e giorni UTC (contratto 3.1), e i nomi dei piani, delle
//  azioni e degli agenti. Sempre con una lingua esplicita: i test non dipendono da quella del Mac.
//

import Foundation
import Testing
@testable import AriaLite

@Suite("Usage formatting")
struct AdminUsageFormatTests {
    private let en = UsageFixture.english
    private let it = UsageFixture.italian
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    // MARK: Crediti e numeri

    @Test func creditsHaveOneDecimalAtMostAndGrouping() {
        #expect(AdminUsageFormat.credits(1700, locale: en) == "1,700")
        #expect(AdminUsageFormat.credits(d("38.4"), locale: en) == "38.4")
        #expect(AdminUsageFormat.credits(d("212.9"), locale: en) == "212.9")
        #expect(AdminUsageFormat.credits(0, locale: en) == "0")
        #expect(AdminUsageFormat.credits(d("38.4"), locale: it) == "38,4")
    }

    @Test func creditsRoundHalfUpToOneDecimal() {
        #expect(AdminUsageFormat.credits(d("38.46"), locale: en) == "38.5")
        // Il mezzo va verso l'alto come `Intl`, non verso il pari come ICU.
        #expect(AdminUsageFormat.credits(d("2.25"), locale: en) == "2.3")
        #expect(AdminUsageFormat.credits(d("2.35"), locale: en) == "2.4")
    }

    @Test func wholeNumbersAndSharesAndThresholds() {
        #expect(AdminUsageFormat.whole(1628, locale: en) == "1,628")
        #expect(AdminUsageFormat.percent(d("0.73")) == 73)
        #expect(AdminUsageFormat.percent(d("0.7312")) == 73)
        #expect(AdminUsageFormat.thresholdPercent(d("0.7"), locale: en) == "70")
        #expect(AdminUsageFormat.thresholdPercent(d("0.625"), locale: en) == "62.5")
        #expect(AdminUsageFormat.thresholdPercent(d("0.625"), locale: it) == "62,5")
    }

    // MARK: Importi

    @Test func aPriceOrALimitDropsWholeCentsAndKeepsTheOthers() {
        #expect(AdminUsageFormat.money(500, currency: "EUR", locale: en) == "€500")
        #expect(AdminUsageFormat.money(0, currency: "EUR", locale: en) == "€0")
        #expect(AdminUsageFormat.money(d("0.16"), currency: "EUR", locale: en) == "€0.16")
    }

    @Test func anAmountBilledOrProjectedAlwaysHasTwoDecimals() {
        #expect(AdminUsageFormat.amount(d("181.97"), currency: "EUR", locale: en) == "€181.97")
        #expect(AdminUsageFormat.amount(28, currency: "EUR", locale: en) == "€28.00")
        #expect(AdminUsageFormat.amount(0, currency: "EUR", locale: en) == "€0.00")
    }

    // MARK: Byte

    @Test func bytesAreGigabytesDividedByABillionWithOneDecimal() {
        #expect(AdminUsageFormat.gigabytes(2_100_000_000, locale: en) == "2.1 GB")
        #expect(AdminUsageFormat.gigabytes(3_000_000_000, locale: en) == "3 GB")
        #expect(AdminUsageFormat.gigabytes(2_100_000_000, locale: it) == "2,1 GB")
    }

    @Test func whatIsLeftRoundsDownAndWhatIsOverRoundsUpNeverReadingZero() {
        #expect(AdminUsageFormat.gigabytes(30_000_000, rounding: .down, locale: en) == "0.03 GB")
        #expect(AdminUsageFormat.gigabytes(40_000_000, rounding: .up, locale: en) == "0.04 GB")
        #expect(AdminUsageFormat.gigabytes(440_000_000, rounding: .up, locale: en) == "0.5 GB")
        #expect(AdminUsageFormat.gigabytes(2_690_000_000, rounding: .down, locale: en) == "2.6 GB")
    }

    // MARK: Giorni UTC

    @Test func aDayIsReadAtUTCMidnightWhateverTheDeviceZone() throws {
        #expect(AdminUsageFormat.date(fromDay: "2026-11-30") == AriaDate.parse("2026-11-30T00:00:00Z"))
        #expect(AdminUsageFormat.date(fromDay: "2026-12-01T00:00:00Z") == AriaDate.parse("2026-12-01T00:00:00Z"))
        #expect(AdminUsageFormat.date(fromDay: "nonsense") == nil)
    }

    @Test func aDayNearMidnightDoesNotShift() {
        // Un telefono a ovest di Greenwich scriverebbe il 29, uno a est scriverebbe l'1 dicembre.
        #expect(AdminUsageFormat.shortDay("2026-11-30", locale: en) == "Nov 30")
        #expect(AdminUsageFormat.shortDay("2026-12-01", locale: en) == "Dec 1")
        #expect(AdminUsageFormat.dayWithYear("2026-11-09", locale: en) == "Nov 9, 2026")
        #expect(AdminUsageFormat.monthYear("2026-11-30", locale: en) == "November 2026")
        #expect(AdminUsageFormat.monthYear("2026-12-01", locale: en) == "December 2026")
        let monday = AriaDate.parse("2026-11-23T00:00:00Z")!
        #expect(AdminUsageFormat.weekDay(monday, locale: en) == "Mon, Nov 23")
    }

    @Test func italianWritesTheFirstOfAMonthWithTheOrdinalSign() {
        #expect(AdminUsageFormat.shortDay("2026-12-01", locale: it) == "1° dic")
        #expect(AdminUsageFormat.shortDay("2026-11-18", locale: it) == "18 nov")
        #expect(AdminUsageFormat.shortDay("2026-11-11", locale: it) == "11 nov")
        #expect(AdminUsageFormat.monthYear("2026-11-30", locale: it) == "novembre 2026")
    }

    @Test func theDayAfterAndTheDayCountsAreUTC() {
        #expect(AdminUsageFormat.nextDay("2026-11-30") == "2026-12-01")
        #expect(AdminUsageFormat.nextDay("2026-02-28") == "2026-03-01")
        #expect(AdminUsageFormat.nextDay("2028-02-28") == "2028-02-29")
        #expect(AdminUsageFormat.days(from: "2026-11-18", to: "2026-11-30") == 12)
        #expect(AdminUsageFormat.days(from: "2026-11-30", to: "2026-11-30") == 0)
        #expect(AdminUsageFormat.days(inCycleFrom: "2026-11-29", to: "2026-12-02")
                == ["2026-11-29", "2026-11-30", "2026-12-01", "2026-12-02"])
    }

    // MARK: Italiano

    @Test func italianElidesTheArticleBeforeEightyElevenAndEighteenPercent() {
        #expect(AdminUsageFormat.elide("Hai usato il 82% dei crediti", locale: it) == "Hai usato l'82% dei crediti")
        #expect(AdminUsageFormat.elide("Il 80% dei crediti", locale: it) == "L'80% dei crediti")
        #expect(AdminUsageFormat.elide("fino al 18%", locale: it) == "fino all'18%")
        #expect(AdminUsageFormat.elide("del 11%", locale: it) == "dell'11%")
        // Le altre quote non cambiano, e le altre lingue passano com'è.
        #expect(AdminUsageFormat.elide("Hai usato il 70% dei crediti", locale: it) == "Hai usato il 70% dei crediti")
        #expect(AdminUsageFormat.elide("Hai usato il 82% dei crediti", locale: en) == "Hai usato il 82% dei crediti")
    }

    // MARK: Nomi

    @Test func planNamesAreLocalizedAndAnUnknownKeyIsShownAsSent() {
        #expect(AdminUsageWords.planName("professional") == "Professional")
        #expect(AdminUsageWords.planName("basic_plus") == "Basic Plus")
        #expect(AdminUsageWords.planName("free_demo") == "Free Demo")
        #expect(AdminUsageWords.planName("starter_2027") == "starter_2027")
    }

    @Test func actionKeysHaveTheirDotsTurnedToUnderscores() {
        #expect(AdminUsageWords.actionName("chat.reply") == "Chat replies")
        #expect(AdminUsageWords.actionName("rag.diagnostic") == "Diagnostics")
        #expect(AdminUsageWords.actionName("doc.generate_async") == "Background documents")
        #expect(AdminUsageWords.actionName("something.new") == "something.new")
        #expect(AdminUsageWords.actionName(nil) == "Not attributed")
    }

    @Test func agentNames() {
        #expect(AdminUsageWords.agentName(key: "agent:general", label: nil) == "AriA")
        #expect(AdminUsageWords.agentName(key: "agent:predictive", label: nil) == "Predictive maintenance")
        #expect(AdminUsageWords.agentName(key: "agent:reporter", label: nil) == "Reporting")
        #expect(AdminUsageWords.agentName(key: "agent:technical", label: nil) == "Technical")
        #expect(AdminUsageWords.agentName(key: "agent:mystery", label: nil) == "mystery")
        #expect(AdminUsageWords.agentName(key: "workflow:6b0c", label: "Weekly line report") == "Weekly line report")
        #expect(AdminUsageWords.agentName(key: "workflow:6b0c", label: nil) == "Not attributed")
        #expect(AdminUsageWords.agentName(key: nil, label: nil) == "Not attributed")
    }
}
