//
//  AdminUsageNoticeSettingsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Notice settings" (contratto 5.4): i tre avvisi e i loro controlli, "Custom" e "Use platform value", "Standard"
//  solo dove la piattaforma non ha un valore, la validazione della soglia per avviso, l'email spenta senza consegna e le
//  persone nominate. In più: ogni body nasce da una vista che contiene già le modifiche precedenti.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Notice settings")
struct AdminUsageNoticeSettingsTests {
    private func d(_ text: String) -> Decimal { Fx.d(text) }

    private func card(_ settings: AriaNoticeSettings? = nil, input: AdminUsageNoticeSettingsInput = .init(emailEnabled: true),
                      names: @escaping (String) -> AdminUsagePersonName = { _ in .formerMember }) throws -> AdminUsageNoticeSettingsCard {
        AdminUsageNoticeSettingsBuilder.card(try settings ?? Fx.noticeSettings(), input: input, locale: Fx.english, names: names)
    }

    private func notice(_ key: AriaNoticeKey, _ settings: AriaNoticeSettings? = nil,
                        input: AdminUsageNoticeSettingsInput = .init(emailEnabled: true),
                        names: @escaping (String) -> AdminUsagePersonName = { _ in .formerMember }) throws -> AdminUsageNoticeSettingsCard.Notice {
        try #require(card(settings, input: input, names: names).notices.first { $0.key == key })
    }

    /// Le regole del contratto con un valore dell'azienda cambiato in un avviso (`company` dell'impostazione).
    private func settings(_ notice: String, _ setting: String, company: Any) throws -> AriaNoticeSettings {
        var root = try #require(JSONSerialization.jsonObject(with: Data(Fx.noticeSettingsJSON.utf8)) as? [String: Any])
        var rule = try #require(root[notice] as? [String: Any])
        var field = try #require(rule[setting] as? [String: Any])
        field["company"] = company
        field["resolved"] = company
        rule[setting] = field
        root[notice] = rule
        return try JSONDecoder().decode(AriaNoticeSettings.self, from: JSONSerialization.data(withJSONObject: root))
    }

    // MARK: La scheda

    @Test func theThreeNoticesWithTheirTitlesAndWhenTheyFire() throws {
        let value = try card()

        #expect(value.title == "Notice settings")
        #expect(value.description == "How each usage notice reaches your company. A setting you leave alone follows the platform.")
        #expect(value.notices.map(\.key) == [.dailyAllowance, .capApproaching, .overage])
        #expect(value.notices.map(\.title) == ["Daily credits", "Spending limit approaching", "Extra credits"])
        #expect(value.notices[0].firesWhen == "When the company reaches this share of today's included credits. The banner shows to everyone, in credits only.")
        #expect(value.notices[1].firesWhen == "When extra credits this cycle reach this share of the spending limit. The banner shows to owners.")
        #expect(value.notices[2].firesWhen == "When the company starts using extra credits, past its included credits. The banner shows to owners.")
        #expect(value.notices.map(\.threshold.lead) == ["Notify when the company uses", "Notify when extra credits reach", "Notify when the company uses"])
        #expect(value.notices.map(\.threshold.unit) == ["of today's credits", "of the limit", "of included credits"])
    }

    @Test func theDeliverySentenceFollowsEmailDelivery() throws {
        #expect(try card(input: .init(emailEnabled: true)).delivery == "Notices arrive in the app and by email.")
        #expect(try card(input: .init(emailEnabled: false)).delivery == "Notices arrive in the app. Email delivery is coming soon.")
        #expect(try card(input: .init(emailEnabled: false)).deliveryIsEmail == false)
    }

    // MARK: Custom e "Use platform value"

    @Test func aSettingTheCompanyChangedCarriesCustomAndTheWayBackToThePlatformValue() throws {
        let daily = try notice(.dailyAllowance)

        // Il banner dell'azienda è spento, quello della piattaforma acceso.
        #expect(!daily.banner.isOn)
        #expect(daily.banner.customization == .init(isCustom: true, resetLabel: "Use platform value: On"))
        #expect(daily.threshold.text == "60")
        #expect(daily.threshold.customization == .init(isCustom: true, resetLabel: "Use platform value: 80%"))
        // Quello che segue la piattaforma non dice niente.
        #expect(daily.email.customization == .init(isCustom: false, resetLabel: nil))
        #expect(daily.repeatPolicy.customization == .init(isCustom: false, resetLabel: nil))
        #expect(daily.recipients.customization == .init(isCustom: false, resetLabel: nil))
    }

    @Test func usePlatformSettingsShowsOnlyWhereTheCompanyChangedSomething() throws {
        let value = try card()

        // Crediti del giorno (banner, soglia) e crediti extra (repeat) hanno valori dell'azienda; il limite no.
        #expect(value.notices.map(\.showsUsePlatformSettings) == [true, false, true])
        #expect(value.notices[0].usePlatformSettingsLabel == "Use platform settings")
    }

    @Test func aRepeatOverrideNamesThePlatformValueAsStandardWhenItIsNull() throws {
        let overage = try notice(.overage)

        #expect(overage.repeatPolicy.selection == .oncePerWeek)
        #expect(overage.repeatPolicy.customization == .init(isCustom: true, resetLabel: "Use platform value: Standard"))
    }

    @Test func aThresholdOverrideShowsTheCompanysShareAsAPercentWithItsDecimals() throws {
        let value = try notice(.capApproaching, settings("cap_approaching", "threshold", company: "0.625"))

        #expect(value.threshold.text == "62.5")
        #expect(value.threshold.customization.resetLabel == "Use platform value: 80%")
    }

    // MARK: Ripetizione e "Standard"

    @Test func standardIsOfferedOnlyWhereThePlatformsOwnValueIsNull() throws {
        let daily = try notice(.dailyAllowance)
        let cap = try notice(.capApproaching)

        // Crediti del giorno: la piattaforma ha `null`, quindi "Standard" c'è (e vale oggi).
        #expect(daily.repeatPolicy.options.map(\.value) == [nil, .oncePerDay, .oncePerWeek, .oncePerCycle])
        #expect(daily.repeatPolicy.options.map(\.title) == ["Standard", "Once a day", "Once a week", "Once a billing cycle"])
        #expect(daily.repeatPolicy.selection == nil)
        #expect(daily.repeatPolicy.hint == "Once a billing cycle. If extra credits are counted per day, the notice shows in the app each day and is emailed once a billing cycle.")
        // Limite che si avvicina: la piattaforma fissa "once_per_cycle": niente "Standard".
        #expect(cap.repeatPolicy.options.map(\.value) == [.oncePerDay, .oncePerWeek, .oncePerCycle])
        #expect(cap.repeatPolicy.selection == .oncePerCycle)
        #expect(cap.repeatPolicy.hint == nil)
    }

    // MARK: Canali

    @Test func theEmailSwitchIsDisabledWithoutEmailDeliveryAndShowsSoon() throws {
        let off = try notice(.overage, input: .init(emailEnabled: false))
        let on = try notice(.overage, input: .init(emailEnabled: true))

        #expect(!off.email.isEnabled)
        #expect(off.email.chip == "Soon")
        #expect(on.email.isEnabled)
        #expect(on.email.chip == nil)
        #expect(on.email.isOn)
        #expect(on.banner.isEnabled)
        #expect(on.banner.label == "In app")
        #expect(on.email.label == "Email")
    }

    // MARK: Destinatari

    @Test func theRecipientsAreTheRolesOrTheNamedPeople() throws {
        let owners = try notice(.capApproaching)
        let both = try notice(.capApproaching, settings("cap_approaching", "tenant_recipients", company: ["owner", "member"]))
        let named = try notice(.capApproaching, settings("cap_approaching", "user_ids", company: [Fx.marcoId, Fx.giuliaId]),
                               names: { $0 == Fx.marcoId ? .name("Marco Bianchi") : .name("Giulia Ferri") })

        #expect(owners.recipients.label == "Sent to")
        #expect(owners.recipients.text == "Owners")
        #expect(owners.recipients.roles == ["owner"])
        #expect(both.recipients.text == "Owners and members")
        #expect(both.recipients.roles == ["owner", "member"])
        #expect(both.recipients.customization == .init(isCustom: true, resetLabel: "Use platform value: Owners"))
        #expect(named.recipients.text == "Marco Bianchi, Giulia Ferri")
        #expect(named.recipients.userIds == [Fx.marcoId, Fx.giuliaId])
        #expect(named.recipients.customization.isCustom)
    }

    @Test func aNamedPersonWhoIsNoLongerAMemberIsFlaggedOnlyAfterTheServerRefusedThem() throws {
        let json = try settings("overage", "user_ids", company: [Fx.marcoId, "left"])
        let names: (String) -> AdminUsagePersonName = { $0 == Fx.marcoId ? .name("Marco Bianchi") : .formerMember }
        let before = try notice(.overage, json, names: names)
        let after = try notice(.overage, json, input: .init(inactiveIds: ["left"], emailEnabled: true), names: names)

        #expect(before.recipients.text == "Marco Bianchi, Former member")
        #expect(before.recipients.inactiveNotes.isEmpty)
        #expect(after.recipients.inactiveNotes == ["Former member is no longer an active member and can't receive notices. Remove them to save again."])
    }

    @Test func namesStillBeingReadShowAPlaceholder() throws {
        let value = try notice(.overage, settings("overage", "user_ids", company: [Fx.marcoId]), names: { _ in .loading })

        #expect(value.recipients.text == "…")
    }

    // MARK: Soglia

    @Test func theTypedThresholdReplacesTheSavedOneAndShowsItsError() throws {
        let value = try notice(.dailyAllowance, input: .init(thresholdDrafts: [.dailyAllowance: "150"],
                                                              thresholdErrors: [.dailyAllowance: .range], emailEnabled: true))
        let other = try notice(.capApproaching, input: .init(thresholdDrafts: [.dailyAllowance: "150"],
                                                              thresholdErrors: [.dailyAllowance: .range], emailEnabled: true))

        #expect(value.threshold.text == "150")
        #expect(value.threshold.error == "Enter a percentage from 1 to 100.")
        #expect(other.threshold.text == "80")
        #expect(other.threshold.error == nil)
    }

    static let thresholdCases: [(AriaNoticeKey, String, Bool)] = [
        (.dailyAllowance, "1", true), (.dailyAllowance, "100", true), (.dailyAllowance, "62.5", true),
        (.dailyAllowance, "62,5", true), (.dailyAllowance, "0.5", false), (.dailyAllowance, "0", false),
        (.dailyAllowance, "100.5", false), (.dailyAllowance, "150", false), (.dailyAllowance, "62.555", false),
        (.dailyAllowance, "abc", false), (.dailyAllowance, "", false), (.dailyAllowance, "60%", false),
        (.capApproaching, "1", true), (.capApproaching, "100", true), (.capApproaching, "101", false),
        (.capApproaching, "0", false), (.overage, "100", true), (.overage, "250", true), (.overage, "100.5", true),
        (.overage, "99", false), (.overage, "99.99", false), (.overage, "1", false), (.overage, "x", false),
    ]

    @Test(arguments: AdminUsageNoticeSettingsTests.thresholdCases)
    func eachNoticeValidatesItsThreshold(notice: AriaNoticeKey, text: String, isValid: Bool) {
        let result = AdminUsageNoticeThreshold.check(text, notice: notice)

        if isValid {
            guard case .valid = result else {
                Issue.record("\(text) should be valid for \(notice)")
                return
            }
        } else {
            #expect(result == .invalid(AdminUsageNoticeThresholdError.error(for: notice)))
        }
    }

    @Test func theThresholdErrorTextsAndTheValidValueAsAShare() throws {
        #expect(AdminUsageNoticeThresholdError.range.text == "Enter a percentage from 1 to 100.")
        #expect(AdminUsageNoticeThresholdError.overage.text == "Enter 100% or more.")
        #expect(AdminUsageNoticeThreshold.check("62,5", notice: .dailyAllowance) == .valid(percent: d("62.5")))
        #expect(AdminUsageNoticeThresholdError.error(for: .dailyAllowance) == .range)
        #expect(AdminUsageNoticeThresholdError.error(for: .capApproaching) == .range)
        #expect(AdminUsageNoticeThresholdError.error(for: .overage) == .overage)
        // Il body manda la quota esatta: 60 → "0.6", 62.5 → "0.625", 100 → "1".
        let settings = try Fx.noticeSettings()
        let body = try Fx.body(settings.payload(applying: .thresholdPercent(d("62.5")), to: .capApproaching))
        #expect(body.contains(#""cap_approaching":{"threshold":"0.625"}"#))
        #expect(try Fx.body(settings.payload(applying: .thresholdPercent(100), to: .overage)).contains(#""overage":{"repeat":"once_per_week"}"#))
    }

    // MARK: Ogni body nasce da una vista che ha già le modifiche precedenti

    private var allEdits: [(String, AriaNoticeEdit)] {
        [("email", .email(false)), ("banner", .banner(false)), ("threshold", .thresholdPercent(70)),
         ("threshold platform", .thresholdPercent(80)), ("repeat", .repeatPolicy(.oncePerDay)),
         ("roles", .tenantRecipients(["owner", "member"])), ("roles platform", .tenantRecipients(["owner"])),
         ("people", .userIds([Fx.marcoId])), ("no people", .userIds([])),
         ("platform email", .usePlatform(.email)), ("platform banner", .usePlatform(.banner)),
         ("platform threshold", .usePlatform(.threshold)), ("platform repeat", .usePlatform(.repeatPolicy)),
         ("platform roles", .usePlatform(.tenantRecipients)), ("platform people", .usePlatform(.userIds)),
         ("whole notice", .usePlatformForNotice)]
    }

    @Test func foldingABodyIntoTheViewGivesBackTheSameOverridesForEveryEditAndNotice() throws {
        let view = try Fx.noticeSettings()

        for notice in AriaNoticeKey.allCases {
            for (name, edit) in allEdits {
                let body = view.payload(applying: edit, to: notice)
                #expect(view.adopting(body).companyOverrides == body, "\(name) on \(notice)")
            }
        }
    }

    @Test func aSecondEditOnTheFoldedViewKeepsTheFirstOneNotWipesIt() throws {
        let view = try Fx.noticeSettings()
        // La prima modifica non è ancora tornata dal server: la seconda parte dalla vista che la contiene già.
        let first = view.payload(applying: .repeatPolicy(.oncePerDay), to: .capApproaching)
        let second = view.adopting(first).payload(applying: .email(false), to: .overage)

        #expect(second[.capApproaching].repeatPolicy == .oncePerDay)
        #expect(second[.overage].email == false)
        // E quello che l'azienda aveva già resta, per tutti e tre gli avvisi.
        #expect(second[.dailyAllowance].banner == false)
        #expect(second[.dailyAllowance].threshold == d("0.6"))
        #expect(second[.overage].repeatPolicy == .oncePerWeek)
        // Dalla vista vecchia, invece, la prima modifica sparirebbe.
        let wiped = view.payload(applying: .email(false), to: .overage)
        #expect(wiped[.capApproaching].repeatPolicy == nil)
    }

    @Test func aValueEqualToThePlatformsIsNotSentSoLaterPlatformChangesStillReachTheCompany() throws {
        let view = try Fx.noticeSettings()
        let body = view.payload(applying: .thresholdPercent(80), to: .dailyAllowance)

        // 80% è quello della piattaforma: la soglia torna a `null`; il banner dell'azienda resta.
        #expect(body[.dailyAllowance].threshold == nil)
        #expect(body[.dailyAllowance].banner == false)
        #expect(view.adopting(body)[.dailyAllowance].threshold.resolved == d("0.8"))
    }

    @Test func foldingSetsResolvedToTheCompanysValueOrThePlatformsOtherwise() throws {
        let view = try Fx.noticeSettings()
        let body = view.payload(applying: .usePlatformForNotice, to: .dailyAllowance)
        let folded = view.adopting(body)

        #expect(folded.dailyAllowance.banner.company == nil)
        #expect(folded.dailyAllowance.banner.resolved == true)
        #expect(folded.dailyAllowance.threshold.resolved == d("0.8"))
        #expect(folded.dailyAllowance.repeatPolicy.resolved == nil)
        // Un avviso che l'edit non tocca resta com'era.
        #expect(folded.overage == view.overage)
    }

    // MARK: "Sent to": ruoli e persone nominate

    private func peopleList(userIds: [String], query: String = "") throws -> AdminUsageNoticePeopleList {
        let recipients = AdminUsageNoticeSettingsCard.Recipients(
            label: "Sent to", text: "", userIds: userIds, roles: ["owner"],
            customization: .init(isCustom: !userIds.isEmpty, resetLabel: nil), inactiveNotes: [])
        return AdminUsageNoticePeopleBuilder.list(
            recipients: recipients, members: try Fx.members(Fx.fiveMembersJSON), query: query, locale: Fx.english,
            nameOf: { _ in .formerMember })
    }

    @Test func theSheetListsTheRolesAndEveryActiveMemberTickedWhereChosen() throws {
        let list = try peopleList(userIds: [Fx.marcoId])

        #expect(list.roles.map(\.title) == ["Owners", "Members"])
        #expect(list.roles.map(\.isOn) == [true, false])
        #expect(list.people.map(\.name) == ["Giulia Ferri", "Marco Bianchi", "Elena Rossi"])
        #expect(list.people.map(\.isOn) == [false, true, false])
        #expect(list.people.map(\.chip) == ["Owner", "Member", "Member"])
        #expect(list.former.isEmpty)
    }

    @Test func namedPeopleTakeThePlaceOfTheRolesSoTheRolesAreDisabled() throws {
        #expect(try peopleList(userIds: [Fx.marcoId]).rolesDisabled)
        #expect(try !peopleList(userIds: []).rolesDisabled)
    }

    @Test func aChosenPersonWhoIsNoLongerAMemberIsListedFirstTickedAndInactive() throws {
        let list = try peopleList(userIds: ["left-the-company", Fx.marcoId])

        #expect(list.former == [.init(id: "left-the-company", name: "Former member", chip: "Inactive", isInactive: true, isOn: true)])
        #expect(list.people.first { $0.id == Fx.marcoId }?.isOn == true)
        // Sta nell'elenco prima dei membri attivi: la vista la mostra in cima.
        #expect((list.former + list.people).first?.id == "left-the-company")
    }

    @Test func theSearchFiltersMembersAndFormerPeopleByName() throws {
        let list = try peopleList(userIds: ["left-the-company"], query: "elena")

        #expect(list.people.map(\.name) == ["Elena Rossi"])
        #expect(list.former.isEmpty)
        #expect(try peopleList(userIds: ["left-the-company"], query: "former").former.count == 1)
    }

    @Test func theOverageThresholdErrorKeepsThePercentAsAnArgument() {
        #expect(AdminUsageNoticeThresholdError.overage.text == "Enter 100% or more.")
    }
}
