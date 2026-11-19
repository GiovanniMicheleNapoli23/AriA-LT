//
//  UsageBillingModelsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I modelli dei controlli di fatturazione (sezione 5): scheda e storico del tetto, destinatari, regole degli avvisi, i
//  body di salvataggio (l'importo come stringa col punto, il `null` esplicito, il costruttore del body completo) e i
//  rifiuti con codice (sezione 7).
//

import Foundation
import Testing
@testable import AriaLite

@Suite("Spend cap models")
struct UsageSpendCapModelTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    @Test func theContractExampleDecodes() throws {
        let cap = try UsageFixture.decode(AriaSpendCapView.self, UsageFixture.spendCapJSON)

        #expect(cap.amount == 500)
        #expect(cap.creditsEquivalent == 3125)
        #expect(cap.status == .ok)
        #expect(cap.canEdit)
        #expect(cap.currency == "EUR")
        #expect(cap.effectiveFrom == AriaDate.parse("2026-11-03T09:12:44Z"))
        #expect(cap.source == .tenant)
        #expect(cap.origin == .record)
        #expect(cap.suggestion == 1200)
        #expect(cap.minimum == 0)
        #expect(cap.warnShare == d("0.8"))
        #expect(cap.locked == nil)
        #expect(cap.amountsVisible)
        #expect(!cap.isTrial)
    }

    @Test func noLimitIsANilAmountNotZero() throws {
        let cap = try UsageFixture.decode(AriaSpendCapView.self, #"{"amount": null, "status": "none", "can_edit": true}"#)

        #expect(cap.amount == nil)
        #expect(cap.status == .noLimit)
        #expect(cap.creditsEquivalent == nil)
    }

    @Test func missingFieldsFollowSectionEightDefaults() throws {
        let cap = try UsageFixture.decode(AriaSpendCapView.self, #"{"amount": "500", "suggestion": null, "minimum": "0", "locked": null}"#)

        #expect(cap.creditsEquivalent == nil)
        #expect(cap.status == nil)
        #expect(cap.origin == nil)
        #expect(cap.currency == nil)
        #expect(cap.warnShare == nil)
        #expect(cap.effectiveFrom == nil)
        // `can_edit` mancante: `true`, salvo `locked`.
        #expect(cap.canEdit)
    }

    @Test func canEditDefaultsToFalseWhenLockedAndAnExplicitValueWins() throws {
        let trial = try UsageFixture.decode(AriaSpendCapView.self, #"{"amount": "0", "locked": "trial", "source": "trial"}"#)
        let unassigned = try UsageFixture.decode(AriaSpendCapView.self, #"{"amount": null, "locked": "unassigned"}"#)
        let explicitTrue = try UsageFixture.decode(AriaSpendCapView.self, #"{"locked": "trial", "can_edit": true}"#)
        let explicitFalse = try UsageFixture.decode(AriaSpendCapView.self, #"{"locked": null, "can_edit": false}"#)

        #expect(!trial.canEdit)
        #expect(trial.locked == .trial)
        #expect(trial.isTrial)
        #expect(!unassigned.canEdit)
        #expect(unassigned.locked == .unassigned)
        #expect(!unassigned.isTrial)
        #expect(explicitTrue.canEdit)
        #expect(!explicitFalse.canEdit)
    }

    @Test func theTrialIsSeenFromTheSourceToo() throws {
        let cap = try UsageFixture.decode(AriaSpendCapView.self, #"{"amount": "0", "source": "trial"}"#)

        #expect(cap.isTrial)
    }

    @Test func aMemberReadsOnlyTheFirstFourFields() throws {
        let cap = try UsageFixture.decode(AriaSpendCapView.self, """
        {"amount": "500", "credits_equivalent": "3125", "status": "warned", "can_edit": false,
         "currency": null, "effective_from": null, "source": null, "origin": null, "suggestion": null,
         "minimum": null, "warn_share": null, "locked": null, "amounts_visible": false}
        """)

        #expect(cap.amount == 500)
        #expect(cap.status == .warned)
        #expect(!cap.canEdit)
        #expect(cap.suggestion == nil)
        #expect(cap.minimum == nil)
        #expect(!cap.amountsVisible)
    }

    @Test func badFieldsAndUnknownValuesDoNotFailTheCard() throws {
        let cap = try UsageFixture.decode(AriaSpendCapView.self, """
        {"amount": "12a", "status": "melting", "source": "robot", "origin": "magic", "locked": "weird",
         "effective_from": "yesterday", "can_edit": "yes", "minimum": "5"}
        """)

        #expect(cap.amount == nil)
        #expect(cap.status == nil)
        #expect(cap.source == nil)
        #expect(cap.origin == nil)
        #expect(cap.locked == nil)
        #expect(cap.effectiveFrom == nil)
        #expect(cap.canEdit)
        #expect(cap.minimum == 5)
    }

    @Test func theDefaultOriginIsRead() throws {
        let cap = try UsageFixture.decode(AriaSpendCapView.self, #"{"amount": "200", "origin": "default", "source": "super_admin"}"#)

        #expect(cap.origin == .default)
        #expect(cap.source == .superAdmin)
    }

    // MARK: Storico

    @Test func theHistoryExampleDecodes() throws {
        let rows = try UsageFixture.decode([AriaSpendCapChange].self, UsageFixture.spendCapHistoryJSON)

        #expect(rows.count == 2)
        #expect(rows[0].effectiveFrom == AriaDate.parse("2026-11-03T09:12:44Z"))
        #expect(rows[0].setBy == "6720a1f0c2d94e0012ab34cd")
        #expect(rows[0].setByRole == .owner)
        #expect(rows[0].previousAmount == nil)
        #expect(rows[0].amount == 500)
        #expect(rows[0].source == .tenant)
        // Una modifica che toglie il tetto, fatta dall'assistenza: nessun autore e nessun nuovo importo.
        #expect(rows[1].setBy == nil)
        #expect(rows[1].setByRole == .superAdmin)
        #expect(rows[1].previousAmount == 500)
        #expect(rows[1].amount == nil)
        #expect(rows[1].source == .superAdmin)
        // Senza fuso vale UTC, con le frazioni.
        #expect(rows[1].effectiveFrom == AriaDate.parse("2026-10-01T00:00:00.250Z"))
    }

    @Test func aBadHistoryRowIsDroppedByTheLenientWrapper() throws {
        let rows = try UsageFixture.decode([AriaLenient<AriaSpendCapChange>].self,
                                           #"[{"amount": "5", "effective_from": "2026-11-03T09:12:44Z"}, "oops", null, {"amount": null}]"#)

        #expect(rows.compactMap(\.value).count == 2)
    }

    // MARK: Body

    @Test func theAmountGoesAsAStringWithADot() throws {
        #expect(try UsageFixture.body(AriaSpendCapRequest(amount: 500)) == #"{"amount":"500"}"#)
        #expect(try UsageFixture.body(AriaSpendCapRequest(amount: d("12.5"))) == #"{"amount":"12.5"}"#)
        #expect(try UsageFixture.body(AriaSpendCapRequest(amount: d("0"))) == #"{"amount":"0"}"#)
        #expect(try UsageFixture.body(AriaSpendCapRequest(amount: d("1200.75"))) == #"{"amount":"1200.75"}"#)
    }

    @Test func removingTheLimitWritesAnExplicitNull() throws {
        #expect(try UsageFixture.body(AriaSpendCapRequest(amount: nil)) == #"{"amount":null}"#)
    }
}

@Suite("Notice recipients")
struct UsageNoticeRecipientsTests {
    @Test func theContractExampleDecodes() throws {
        let view = try UsageFixture.decode(AriaNoticeRecipients.self, UsageFixture.recipientsJSON)

        #expect(view.userIds == ["6720a1f0c2d94e0012ab34d2"])
        #expect(view.defaultRoles == ["owner"])
        #expect(view.members.count == 2)
        #expect(view.members[0].userId == "6720a1f0c2d94e0012ab34cd")
        #expect(view.members[0].name == "Giulia Ferri")
        #expect(view.members[0].email == "giulia@example.com")
        #expect(view.members[0].role == "owner")
        #expect(view.members[0].isDefault)
        #expect(!view.members[0].isAdded)
        #expect(!view.members[1].isDefault)
        #expect(view.members[1].isAdded)
    }

    @Test func aMemberWithoutAnIdIsDroppedAndTheNameFallsBackToTheEmail() throws {
        let view = try UsageFixture.decode(AriaNoticeRecipients.self, """
        {"user_ids": [], "default_roles": ["owner"], "members": [
          {"email": "x@example.com"}, "oops",
          {"user_id": "u1", "email": "u1@example.com", "name": "  "},
          {"user_id": "u2", "email": null, "name": null}]}
        """)

        #expect(view.members.map(\.userId) == ["u1", "u2"])
        #expect(view.members[0].displayName == "u1@example.com")
        #expect(view.members[1].displayName == nil)
        #expect(!view.members[0].isDefault)
        #expect(!view.members[0].isAdded)
    }

    @Test func anEmptyAnswerIsEmpty() throws {
        let view = try UsageFixture.decode(AriaNoticeRecipients.self, "{}")

        #expect(view.userIds.isEmpty)
        #expect(view.defaultRoles.isEmpty)
        #expect(view.members.isEmpty)
    }

    @Test func theBodyReplacesTheWholeList() throws {
        #expect(try UsageFixture.body(AriaNoticeRecipientsRequest(userIds: ["a", "b"])) == #"{"user_ids":["a","b"]}"#)
        #expect(try UsageFixture.body(AriaNoticeRecipientsRequest(userIds: [])) == #"{"user_ids":[]}"#)
    }
}

@Suite("Notice settings")
struct UsageNoticeSettingsTests {
    private func d(_ text: String) -> Decimal { UsageFixture.d(text) }

    @Test func theContractExampleDecodes() throws {
        let settings = try UsageFixture.noticeSettings()
        let daily = settings.dailyAllowance

        #expect(daily.email == .init(platform: true, company: nil, resolved: true))
        #expect(daily.banner == .init(platform: true, company: false, resolved: false))
        #expect(daily.threshold == .init(platform: d("0.8"), company: d("0.6"), resolved: d("0.6")))
        #expect(daily.repeatPolicy == .init(platform: nil, company: nil, resolved: nil))
        #expect(daily.tenantRecipients == .init(platform: ["owner"], company: nil, resolved: ["owner"]))
        #expect(daily.userIds == .init(platform: nil, company: nil, resolved: nil))
        #expect(daily.banner.isCustom)
        #expect(!daily.email.isCustom)
        #expect(settings[.capApproaching].repeatPolicy.platform == .oncePerCycle)
        #expect(settings[.overage].repeatPolicy == .init(platform: nil, company: .oncePerWeek, resolved: .oncePerWeek))
        #expect(settings[.overage].threshold.resolved == 1)
    }

    @Test func thresholdValuesAreDecimalStringsAndABadOneIsNil() throws {
        let settings = try UsageFixture.decode(AriaNoticeSettings.self, """
        {"daily_allowance": {"threshold": {"platform": "0.80", "company": "sixty", "resolved": 0.6}}}
        """)

        #expect(settings.dailyAllowance.threshold == .init(platform: d("0.8"), company: nil, resolved: d("0.6")))
        // Un avviso o un'impostazione mancante è tutta `nil`: niente errore.
        #expect(settings.overage == AriaNoticeRule())
        #expect(settings.dailyAllowance.email == .init())
    }

    @Test func anUnknownRepeatValueIsNil() throws {
        let settings = try UsageFixture.decode(AriaNoticeSettings.self, """
        {"overage": {"repeat": {"platform": "hourly", "company": "once_per_day", "resolved": "once_per_day"}}}
        """)

        #expect(settings.overage.repeatPolicy == .init(platform: nil, company: .oncePerDay, resolved: .oncePerDay))
    }

    @Test func namedPeopleAreRead() throws {
        let settings = try UsageFixture.decode(AriaNoticeSettings.self, """
        {"overage": {"user_ids": {"platform": null, "company": ["u1", "u2"], "resolved": ["u1", "u2"]},
                     "tenant_recipients": {"platform": ["owner"], "company": ["owner", "member"], "resolved": ["owner", "member"]}}}
        """)

        #expect(settings.overage.userIds.company == ["u1", "u2"])
        #expect(settings.overage.tenantRecipients.resolved == ["owner", "member"])
        #expect(settings.overage.userIds.isCustom)
    }

    @Test func theCompanyOverridesAreTheValuesItKeepsAsItsOwn() throws {
        let overrides = try UsageFixture.noticeSettings().companyOverrides

        #expect(overrides[.dailyAllowance] == AriaNoticeOverride(banner: false, threshold: d("0.6")))
        #expect(overrides[.capApproaching].isEmpty)
        #expect(overrides[.overage] == AriaNoticeOverride(repeatPolicy: .oncePerWeek))
        #expect(try UsageFixture.body(overrides) == #"{"daily_allowance":{"banner":false,"threshold":"0.6"},"overage":{"repeat":"once_per_week"}}"#)
    }

    // MARK: Il body completo

    @Test func changingOneSettingKeepsEveryOverrideOfAllThreeNotices() throws {
        let settings = try UsageFixture.noticeSettings()

        let payload = settings.payload(applying: .email(false), to: .overage)

        #expect(try UsageFixture.body(payload) == #"{"daily_allowance":{"banner":false,"threshold":"0.6"},"overage":{"email":false,"repeat":"once_per_week"}}"#)
    }

    @Test func aNoticeWithoutOverridesAppearsOnceItIsChanged() throws {
        let settings = try UsageFixture.noticeSettings()

        let payload = settings.payload(applying: .repeatPolicy(.oncePerDay), to: .capApproaching)

        #expect(try UsageFixture.body(payload) == """
        {"cap_approaching":{"repeat":"once_per_day"},"daily_allowance":{"banner":false,"threshold":"0.6"},"overage":{"repeat":"once_per_week"}}
        """)
    }

    @Test func aValueEqualToThePlatformsIsSentAsAbsent() throws {
        let settings = try UsageFixture.noticeSettings()

        // La soglia platform dei crediti del giorno è 0.80 (0.8 e 0.80 sono lo stesso numero); il banner platform è true.
        let threshold = settings.payload(applying: .threshold(d("0.80")), to: .dailyAllowance)
        let banner = settings.payload(applying: .banner(true), to: .dailyAllowance)

        #expect(try UsageFixture.body(threshold) == #"{"daily_allowance":{"banner":false},"overage":{"repeat":"once_per_week"}}"#)
        #expect(try UsageFixture.body(banner) == #"{"daily_allowance":{"threshold":"0.6"},"overage":{"repeat":"once_per_week"}}"#)
    }

    @Test func aValueDifferentFromThePlatformsIsSent() throws {
        let settings = try UsageFixture.noticeSettings()

        let payload = settings.payload(applying: .email(false), to: .dailyAllowance)

        #expect(payload[.dailyAllowance] == AriaNoticeOverride(email: false, banner: false, threshold: d("0.6")))
    }

    @Test func rolesEqualToThePlatformsAreTheSameWhateverTheOrder() throws {
        let settings = try UsageFixture.noticeSettings()

        let same = settings.payload(applying: .tenantRecipients(["owner"]), to: .overage)
        let more = settings.payload(applying: .tenantRecipients(["owner", "member"]), to: .overage)

        #expect(same[.overage] == AriaNoticeOverride(repeatPolicy: .oncePerWeek))
        #expect(more[.overage] == AriaNoticeOverride(repeatPolicy: .oncePerWeek, tenantRecipients: ["owner", "member"]))
    }

    @Test func namedPeopleAreSentAndAnEmptyListClearsThem() throws {
        let settings = try UsageFixture.noticeSettings()

        let named = settings.payload(applying: .userIds(["u1"]), to: .capApproaching)
        let cleared = try UsageFixture.decode(AriaNoticeSettings.self, """
        {"overage": {"user_ids": {"platform": null, "company": ["u1"], "resolved": ["u1"]}}}
        """).payload(applying: .userIds([]), to: .overage)

        #expect(named[.capApproaching] == AriaNoticeOverride(userIds: ["u1"]))
        #expect(cleared == AriaNoticeOverrides())
    }

    @Test func usePlatformValueClearsOneSetting() throws {
        let settings = try UsageFixture.noticeSettings()

        let payload = settings.payload(applying: .usePlatform(.threshold), to: .dailyAllowance)

        #expect(try UsageFixture.body(payload) == #"{"daily_allowance":{"banner":false},"overage":{"repeat":"once_per_week"}}"#)
    }

    @Test func usePlatformSettingsClearsOneWholeNoticeAndKeepsTheOthers() throws {
        let settings = try UsageFixture.noticeSettings()

        let payload = settings.payload(applying: .usePlatformForNotice, to: .dailyAllowance)

        #expect(try UsageFixture.body(payload) == #"{"overage":{"repeat":"once_per_week"}}"#)
    }

    @Test func clearingEveryOverrideIsAnEmptyObject() throws {
        let onlyDaily = try UsageFixture.decode(AriaNoticeSettings.self, """
        {"daily_allowance": {"banner": {"platform": true, "company": false, "resolved": false}}}
        """)

        let cleared = onlyDaily.payload(applying: .usePlatform(.banner), to: .dailyAllowance)

        #expect(try UsageFixture.body(cleared) == "{}")
        #expect(try UsageFixture.body(AriaNoticeOverrides()) == "{}")
        #expect(try UsageFixture.body(try UsageFixture.noticeSettings("{}").companyOverrides) == "{}")
    }

    @Test func aPercentIsSentAsAShare() throws {
        let settings = try UsageFixture.noticeSettings()

        func threshold(_ percent: String, _ notice: AriaNoticeKey) throws -> String {
            try UsageFixture.body(settings.payload(applying: .thresholdPercent(d(percent)), to: notice))
        }

        #expect(try threshold("62.5", .capApproaching).contains(#""cap_approaching":{"threshold":"0.625"}"#))
        #expect(try threshold("60", .capApproaching).contains(#""cap_approaching":{"threshold":"0.6"}"#))
        #expect(try threshold("150", .overage).contains(#""overage":{"repeat":"once_per_week","threshold":"1.5"}"#))
        // 100% es. la soglia platform degli extra è 1: uguale, quindi assente.
        #expect(try threshold("100", .overage).contains(#""overage":{"repeat":"once_per_week"}"#))
        // Per i crediti del giorno 100 è diverso dalla platform (0.80): si manda "1".
        #expect(try threshold("100", .dailyAllowance).contains(#""daily_allowance":{"banner":false,"threshold":"1"}"#))
    }

    @Test func settingARepeatWhereThePlatformHasOneEqualToItDropsIt() throws {
        let settings = try UsageFixture.decode(AriaNoticeSettings.self, """
        {"cap_approaching": {"repeat": {"platform": "once_per_cycle", "company": "once_per_week", "resolved": "once_per_week"}}}
        """)

        let same = settings.payload(applying: .repeatPolicy(.oncePerCycle), to: .capApproaching)
        let other = settings.payload(applying: .repeatPolicy(.oncePerDay), to: .capApproaching)

        #expect(same == AriaNoticeOverrides())
        #expect(other[.capApproaching] == AriaNoticeOverride(repeatPolicy: .oncePerDay))
    }
}

@Suite("Usage refusals")
struct UsageRefusalTests {
    @Test func aPlainStringDetailIsTheText() {
        let body = AriaUsageErrorBody(data: Data(#"{"detail": "Usage figures unavailable"}"#.utf8))

        #expect(body.text == "Usage figures unavailable")
        #expect(body.code == nil)
        #expect(body.minimum == nil)
        #expect(body.userIds.isEmpty)
    }

    @Test func anObjectDetailCarriesTheCodeAndItsExtras() {
        let minimum = AriaUsageErrorBody(data: Data(#"{"detail": {"code": "spend_cap_below_minimum", "minimum": "50"}}"#.utf8))
        let users = AriaUsageErrorBody(data: Data(#"{"detail": {"code": "recipient_not_active_member", "user_ids": ["u1", "u2", 7]}}"#.utf8))
        let notice = AriaUsageErrorBody(data: Data(#"{"detail": {"code": "notice_threshold_out_of_range", "notice": "cap_approaching", "expected": "(0, 1]"}}"#.utf8))

        #expect(minimum.code == "spend_cap_below_minimum")
        #expect(minimum.minimum == 50)
        #expect(minimum.text == nil)
        #expect(users.userIds == ["u1", "u2"])
        #expect(notice.notice == .capApproaching)
        #expect(notice.expected == "(0, 1]")
    }

    @Test func aMessageInAnObjectIsTheText() {
        let body = AriaUsageErrorBody(data: Data(#"{"detail": {"code": "operation_forbidden", "message": "Not on the phone"}}"#.utf8))

        #expect(body.code == "operation_forbidden")
        #expect(body.text == "Not on the phone")
    }

    @Test(arguments: ["", "not json", "{}", "[]", #"{"detail": null}"#, #"{"detail": 5}"#, #"{"detail": [{"msg": "x"}]}"#])
    func anythingElseIsEmptyAndNeverFails(raw: String) {
        let body = AriaUsageErrorBody(data: Data(raw.utf8))

        #expect(body.code == nil)
        #expect(body.text == nil)
        #expect(AriaUsageRefusal(Data(raw.utf8)) == nil)
    }

    @Test func aKnownCodeIsARefusalWithItsExtras() throws {
        let below = try #require(AriaUsageRefusal(Data(#"{"detail": {"code": "spend_cap_below_minimum", "minimum": "120.5"}}"#.utf8)))
        let inactive = try #require(AriaUsageRefusal(Data(#"{"detail": {"code": "recipient_not_active_member", "user_ids": ["u9"]}}"#.utf8)))
        let range = try #require(AriaUsageRefusal(Data(#"{"detail": {"code": "notice_threshold_out_of_range", "notice": "overage", "expected": "[1, inf)"}}"#.utf8)))

        #expect(below.code == .spendCapBelowMinimum)
        #expect(below.minimum == UsageFixture.d("120.5"))
        #expect(inactive.code == .recipientNotActiveMember)
        #expect(inactive.userIds == ["u9"])
        #expect(range.code == .noticeThresholdOutOfRange)
        #expect(range.notice == .overage)
        #expect(range.expected == "[1, inf)")
    }

    @Test func aStringDetailOrAnUnknownCodeIsNotARefusal() {
        #expect(AriaUsageRefusal(Data(#"{"detail": "spend_cap_required"}"#.utf8)) == nil)
        #expect(AriaUsageRefusal(Data(#"{"detail": {"code": "something_else"}}"#.utf8)) == nil)
    }

    @Test(arguments: AriaUsageRefusal.Code.allCases)
    func everyRefusalHasAMessage(code: AriaUsageRefusal.Code) {
        #expect(!AriaUsageRefusal(code: code).message.isEmpty)
    }

    // MARK: Il percorso di AriaHTTP.check

    @Test(arguments: [
        (409, "spend_cap_locked_trial", AriaUsageRefusal.Code.spendCapLockedTrial),
        (409, "spend_cap_locked_unassigned", AriaUsageRefusal.Code.spendCapLockedUnassigned),
        (422, "spend_cap_required", AriaUsageRefusal.Code.spendCapRequired),
        (422, "spend_cap_below_minimum", AriaUsageRefusal.Code.spendCapBelowMinimum),
        (422, "recipient_not_active_member", AriaUsageRefusal.Code.recipientNotActiveMember),
        (422, "notice_threshold_out_of_range", AriaUsageRefusal.Code.noticeThresholdOutOfRange),
    ])
    func theNetworkLayerRaisesTheUsageRefusal(status: Int, raw: String, expected: AriaUsageRefusal.Code) throws {
        let error = try #require(UsageFixture.httpError(status, #"{"detail": {"code": "\#(raw)"}}"#))

        guard case .usageRefused(let refusal) = error else { Issue.record("atteso .usageRefused, trovato \(error)"); return }
        #expect(refusal.code == expected)
        #expect(error.errorDescription == refusal.message)
    }

    @Test func theExtrasSurviveTheNetworkLayer() throws {
        let below = try #require(UsageFixture.httpError(422, #"{"detail": {"code": "spend_cap_below_minimum", "minimum": "50"}}"#))
        let inactive = try #require(UsageFixture.httpError(422, #"{"detail": {"code": "recipient_not_active_member", "user_ids": ["u1"]}}"#))

        guard case .usageRefused(let minimum) = below, case .usageRefused(let people) = inactive else {
            Issue.record("atteso .usageRefused"); return
        }
        #expect(minimum.minimum == 50)
        #expect(people.userIds == ["u1"])
    }

    @Test func theOtherUsageErrorsKeepTheirOwnMechanism() throws {
        // 503 con testo semplice: un errore HTTP generico, col testo del server.
        let unavailable = try #require(UsageFixture.httpError(503, #"{"detail": "Usage unavailable"}"#))
        // 403 operation_forbidden: la funzione non è aperta al telefono.
        let forbidden = try #require(UsageFixture.httpError(403, #"{"detail": {"code": "operation_forbidden", "message": "x"}}"#))
        let ended = try #require(UsageFixture.httpError(403, #"{"detail": {"code": "session_ended", "message": "x"}}"#))
        let insufficient = try #require(UsageFixture.httpError(403, #"{"detail": "Insufficient role"}"#))

        guard case .http(let status, let detail) = unavailable else { Issue.record("atteso .http, trovato \(unavailable)"); return }
        #expect(status == 503)
        #expect(detail == "Usage unavailable")
        guard case .notOnPhone = forbidden else { Issue.record("atteso .notOnPhone, trovato \(forbidden)"); return }
        guard case .sessionEnded = ended else { Issue.record("atteso .sessionEnded, trovato \(ended)"); return }
        guard case .http(403, _) = insufficient else { Issue.record("atteso .http 403, trovato \(insufficient)"); return }
    }

    @Test func aUsageCodeOnA403IsNotARefusal() throws {
        let error = try #require(UsageFixture.httpError(403, #"{"detail": {"code": "spend_cap_required"}}"#))

        if case .usageRefused = error { Issue.record("un 403 non è un rifiuto del tetto") }
    }
}
