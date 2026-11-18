//
//  UsageTurnTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'evento `aria.turn_usage` di una risposta: lettura (cosa si scarta), unione delle riprese, la nota sotto la
//  risposta riga per riga della tabella del contratto e l'avviso di un livello abbassato.
//

import Foundation
import Testing
@testable import AriaLite

private func eventJSON(credits: String = #""2.4""#, status: String = #""charged""#, actionStatus: String? = #""completed""#,
                       overage: Bool = false, continuation: Bool = false, effort: String? = nil,
                       degradedModel: Bool = false) -> String {
    let block = effort ?? #"{"requested":"high","effective":"high","degraded":false,"multiplier":"2.4","reason":null}"#
    let action = actionStatus.map { #""action_status":\#($0),"# } ?? ""
    return """
    {"type":"aria.turn_usage","action_id":"a1","action_type":"chat.reply","status":\(status),\(action)
     "credits":\(credits),"overage":\(overage),"continuation":\(continuation),
     "effort":\(block),"degraded_model":\(degradedModel),"compaction":null,"truncation":null,"suggest":null}
    """
}

private func usage(_ json: String) throws -> AriaTurnUsage? {
    AriaTurnUsage(json: try UsageFixture.json(json))
}

@Suite("Turn usage")
struct UsageTurnUsageTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    @Test func aGoodEventIsReadAsSent() throws {
        let event = try #require(try usage(eventJSON()))

        #expect(event.actionType == "chat.reply")
        #expect(event.status == .charged)
        #expect(event.actionStatus == .completed)
        #expect(event.credits == d("2.4"))
        #expect(!event.overage)
        #expect(!event.continuation)
        #expect(!event.degradedModel)
        #expect(event.effort == AriaTurnUsage.Effort(requested: .high, effective: .high, degraded: false,
                                                     multiplier: d("2.4"), reason: nil))
    }

    @Test func theFlagsAndTheFreeStatusAreRead() throws {
        let event = try #require(try usage(eventJSON(credits: #""0""#, status: #""not_charged""#, actionStatus: #""cancelled""#,
                                                     overage: true, continuation: true, degradedModel: true)))

        #expect(event.status == .notCharged)
        #expect(event.actionStatus == .cancelled)
        #expect(event.overage)
        #expect(event.continuation)
        #expect(event.degradedModel)
    }

    @Test func creditsMayBeAJSONNumber() throws {
        #expect(try usage(eventJSON(credits: "2.4"))?.credits == d("2.4"))
        #expect(try usage(eventJSON(credits: "3"))?.credits == 3)
    }

    @Test(arguments: [#""-1""#, #""abc""#, #""2.4abc""#, #""1e3""#, #""""#, "null", "true", "-0.5", #"["2.4"]"#])
    func unreadableCreditsDiscardTheEvent(credits: String) throws {
        #expect(try usage(eventJSON(credits: credits)) == nil)
    }

    @Test func missingCreditsDiscardTheEvent() throws {
        let json = #"{"status":"charged","effort":{"effective":"base"}}"#
        #expect(try usage(json) == nil)
    }

    @Test(arguments: [#""refunded""#, #""""#, "null", "1"])
    func anUnknownStatusDiscardsTheEvent(status: String) throws {
        #expect(try usage(eventJSON(status: status)) == nil)
    }

    @Test func anUnknownActionStatusDiscardsTheEventButAMissingOneDoesNot() throws {
        #expect(try usage(eventJSON(actionStatus: #""paused""#)) == nil)
        #expect(try usage(eventJSON(actionStatus: "5")) == nil)

        let missing = try #require(try usage(eventJSON(actionStatus: nil)))
        #expect(missing.actionStatus == nil)
        let null = try #require(try usage(eventJSON(actionStatus: "null")))
        #expect(null.actionStatus == nil)
    }

    @Test func aLevelTheAppCannotNameDiscardsTheEvent() throws {
        #expect(try usage(eventJSON(effort: #"{"requested":"high","effective":"ultra"}"#)) == nil)
        #expect(try usage(eventJSON(effort: #"{"requested":"high"}"#)) == nil)
        #expect(try usage(eventJSON(effort: #"{"effective":7}"#)) == nil)
        #expect(try usage(eventJSON(effort: #""high""#)) == nil)
    }

    @Test func aMissingRequestedLevelFallsBackToTheEffectiveOne() throws {
        let event = try #require(try usage(eventJSON(effort: #"{"effective":"medium","degraded":false}"#)))
        #expect(event.effort?.requested == .medium)
        #expect(event.effort?.effective == .medium)

        let unknown = try #require(try usage(eventJSON(effort: #"{"requested":"ultra","effective":"base"}"#)))
        #expect(unknown.effort?.requested == .base)
    }

    @Test func aReplyWithoutAnEffortBlockIsDiscarded() throws {
        // Come turnUsageOf della web: senza `effort` l'evento è illeggibile.
        #expect(try usage(#"{"status":"charged","credits":"1.0","overage":false}"#) == nil)
        #expect(try usage(#"{"status":"charged","credits":"1.0","effort":null}"#) == nil)
    }

    @Test func aDegradedEffortKeepsItsReason() throws {
        let event = try #require(try usage(eventJSON(
            effort: #"{"requested":"high","effective":"base","degraded":true,"multiplier":"1.0","reason":"tier"}"#)))

        #expect(event.effort?.degraded == true)
        #expect(event.effort?.requested == .high)
        #expect(event.effort?.effective == .base)
        #expect(event.effort?.reason == "tier")
    }

    @Test func aNonObjectIsNotAnEvent() throws {
        #expect(AriaTurnUsage(json: .null) == nil)
        #expect(AriaTurnUsage(json: .string("charged")) == nil)
        #expect(AriaTurnUsage(json: .array([])) == nil)
    }

    // MARK: Riprese

    @Test func aContinuationKeepsTheEarlierChargeAndTakesTheRest() throws {
        let earlier = try #require(try usage(eventJSON(credits: #""2.4""#, overage: true, effort:
            #"{"requested":"high","effective":"high","degraded":false}"#)))
        let next = try #require(try usage(eventJSON(credits: #""0""#, status: #""not_charged""#, continuation: true,
                                                    effort: #"{"requested":"high","effective":"base","degraded":true,"reason":"spend_cap"}"#,
                                                    degradedModel: true)))

        let merged = try #require(AriaTurnUsage.merged(earlier, with: next))

        #expect(merged.credits == d("2.4"))
        #expect(merged.status == .charged)
        #expect(merged.overage)
        #expect(!merged.continuation)
        #expect(merged.effort?.effective == .base)
        #expect(merged.effort?.reason == "spend_cap")
        #expect(merged.degradedModel)
    }

    @Test func aContinuationWithNoEarlierEventSaysNothing() throws {
        let next = try #require(try usage(eventJSON(credits: #""0""#, status: #""not_charged""#, continuation: true)))

        #expect(AriaTurnUsage.merged(nil, with: next) == nil)
        #expect(AriaTurnUsage.folded([next]) == nil)
    }

    @Test func anEventThatIsNotAContinuationReplacesTheEarlierOne() throws {
        let earlier = try #require(try usage(eventJSON(credits: #""2.4""#)))
        let next = try #require(try usage(eventJSON(credits: #""1.0""#)))

        #expect(AriaTurnUsage.merged(earlier, with: next) == next)
        #expect(AriaTurnUsage.merged(nil, with: next) == next)
    }

    @Test func foldingReducesAReplysEventsInOrder() throws {
        let charged = try #require(try usage(eventJSON(credits: #""2.4""#)))
        let resumed = try #require(try usage(eventJSON(credits: #""0""#, status: #""not_charged""#, continuation: true)))

        let folded = try #require(AriaTurnUsage.folded([charged, resumed, resumed]))

        #expect(folded.credits == d("2.4"))
        #expect(folded.status == .charged)
        #expect(AriaTurnUsage.folded([]) == nil)
        #expect(AriaTurnUsage.folded([charged]) == charged)
    }
}

@Suite("Turn credit note")
struct UsageCreditNoteTests {
    private let en = UsageFixture.english

    private func makeNote(_ json: String, config: AriaUsageConfig? = try? UsageFixture.config()) throws -> AriaTurnCreditNote? {
        let event = try usage(json)
        return AriaTurnCreditNote.make(usage: event, config: config, locale: en)
    }

    private let base = #"{"requested":"base","effective":"base","degraded":false,"multiplier":"1.0","reason":null}"#
    private let high = #"{"requested":"high","effective":"high","degraded":false,"multiplier":"2.4","reason":null}"#
    private let lowered = #"{"requested":"high","effective":"base","degraded":true,"multiplier":"1.0","reason":"tier"}"#

    @Test func aChargedReplyShowsItsCredits() throws {
        #expect(try makeNote(eventJSON(credits: #""1""#, effort: base)) == AriaTurnCreditNote(text: "1 credit", tags: []))
        #expect(try makeNote(eventJSON(credits: #""2.4""#, effort: base)) == AriaTurnCreditNote(text: "2.4 credits", tags: []))
        #expect(try makeNote(eventJSON(credits: #""1.0""#, effort: base))?.text == "1 credit")
    }

    @Test func effortAboveBaseIsNamed() throws {
        let note = try #require(try makeNote(eventJSON(effort: high)))
        #expect(note.text == "2.4 credits · Effort: High")
        #expect(note.tags.isEmpty)
    }

    @Test func aLoweredEffortSaysSoInsteadOfNamingTheEffort() throws {
        let note = try #require(try makeNote(eventJSON(credits: #""1""#, effort: lowered)))
        #expect(note.text == "1 credit · High effort unavailable, ran at Base")
    }

    @Test func extraCreditsTagNeedsCustomerVisibility() throws {
        let visible = try #require(try makeNote(eventJSON(overage: true, effort: base)))
        #expect(visible.tags == ["Extra credits"])

        let hiddenConfig = try UsageFixture.config(#"{"billing": {"customer_visibility": false}}"#)
        #expect(try makeNote(eventJSON(overage: true, effort: base), config: hiddenConfig)?.tags == [])
        // Finché la config non si conosce la nota c'è, ma senza il tag.
        let unknown = try #require(try makeNote(eventJSON(overage: true, effort: base), config: nil))
        #expect(unknown.text == "2.4 credits")
        #expect(unknown.tags.isEmpty)
    }

    @Test func aLighterModelHasItsTag() throws {
        let note = try #require(try makeNote(eventJSON(effort: base, degradedModel: true)))
        #expect(note.tags == ["Lighter model"])

        let both = try #require(try makeNote(eventJSON(overage: true, effort: lowered, degradedModel: true)))
        #expect(both.text == "2.4 credits · High effort unavailable, ran at Base")
        #expect(both.tags == ["Extra credits", "Lighter model"])
    }

    @Test func aStoppedFreeReplyHasNoFigure() throws {
        let note = try #require(try makeNote(eventJSON(credits: #""0""#, status: #""not_charged""#, actionStatus: #""cancelled""#,
                                                   overage: true, effort: high, degradedModel: true)))
        #expect(note == AriaTurnCreditNote(text: "Stopped · Not charged", tags: []))
    }

    @Test func aFreeCompletedReplyShowsTheFigureAsSent() throws {
        let note = try #require(try makeNote(eventJSON(credits: #""0""#, status: #""not_charged""#, effort: base)))
        #expect(note.text == "0 credits")
    }

    @Test func aFreeReplyWithNoActionStatusIsNotStopped() throws {
        // `action_status` mancante vale "completata": la cifra come inviata, mai "Stopped".
        let note = try #require(try makeNote(eventJSON(credits: #""0""#, status: #""not_charged""#, actionStatus: nil, effort: base)))
        #expect(note.text == "0 credits")
        #expect(note.tags.isEmpty)
    }

    @Test func aFreeFailureHasNoNote() throws {
        #expect(try makeNote(eventJSON(credits: #""0""#, status: #""not_charged""#, actionStatus: #""failed""#)) == nil)
    }

    @Test func aChargedCancelledReplyReadsAsAnyChargedOne() throws {
        let note = try #require(try makeNote(eventJSON(actionStatus: #""cancelled""#, effort: base)))
        #expect(note.text == "2.4 credits")
    }

    @Test func aLoneContinuationHasNoNote() throws {
        #expect(try makeNote(eventJSON(credits: #""0""#, status: #""not_charged""#, continuation: true)) == nil)
    }

    @Test func theMergedContinuationShowsTheEarlierCharge() throws {
        let earlier = try #require(try usage(eventJSON(credits: #""2.4""#, effort: high)))
        let next = try #require(try usage(eventJSON(credits: #""0""#, status: #""not_charged""#, continuation: true, effort: high)))
        let folded = AriaTurnUsage.folded([earlier, next])

        let config = try UsageFixture.config()
        let note = try #require(AriaTurnCreditNote.make(usage: folded, config: config, locale: en))
        #expect(note.text == "2.4 credits · Effort: High")
    }

    @Test func noEventOrAnOffConfigMeansNoNote() throws {
        let config = try UsageFixture.config()
        #expect(AriaTurnCreditNote.make(usage: nil, config: config, locale: en) == nil)

        let off = try UsageFixture.config(#"{"ui": {"credit_note_mode": "off"}}"#)
        #expect(try makeNote(eventJSON(effort: base), config: off) == nil)
        #expect(try makeNote(eventJSON(effort: base), config: nil) != nil)
    }
}

@Suite("Effort notice")
struct UsageEffortNoticeTests {
    private func effort(degraded: Bool, reason: String?) -> AriaTurnUsage.Effort {
        AriaTurnUsage.Effort(requested: .high, effective: .base, degraded: degraded, multiplier: nil, reason: reason)
    }

    @Test func aReplyThatRanAtTheRequestedLevelHasNoNotice() {
        #expect(AriaEffortNotice.degradedSentence(effort(degraded: false, reason: "tier")) == nil)
    }

    @Test func tierSpendCapAndOtherReasonsHaveTheirSentence() {
        #expect(AriaEffortNotice.degradedSentence(effort(degraded: true, reason: "tier"))
                == "You asked for High, but it isn’t available on your plan, so this reply ran at Base.")
        #expect(AriaEffortNotice.degradedSentence(effort(degraded: true, reason: "spend_cap"))
                == "You asked for High, but your company’s spending limit is reached, so this reply ran at Base on a lighter model.")
        #expect(AriaEffortNotice.degradedSentence(effort(degraded: true, reason: "not_applied"))
                == "You asked for High, but it couldn’t be applied, so this reply ran at Base.")
        #expect(AriaEffortNotice.degradedSentence(effort(degraded: true, reason: nil))
                == "You asked for High, but it couldn’t be applied, so this reply ran at Base.")
    }
}
