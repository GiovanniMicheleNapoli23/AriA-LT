//
//  AdminUsageNoticeRecipientsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  La scheda "Usage notices" (contratto 5.3): chi è sempre avvisato, chi si avvisa in più, aggiungere e togliere (la lista
//  intera che parte), "Add a member" (chi manca, con la ricerca), i membri rifiutati dal server segnati "Inactive" e la frase
//  di consegna.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Notice recipients")
struct AdminUsageNoticeRecipientsTests {
    private func members() throws -> [AriaNoticeRecipients.Member] { try Fx.members(Fx.fiveMembersJSON) }

    private func card(_ members: [AriaNoticeRecipients.Member], ids: [String]? = nil, refused: [AdminUsageRefusedPerson] = [],
                      email: Bool = true) -> AdminUsageNoticeRecipientsCard {
        AdminUsageNoticeRecipientsBuilder.card(
            members: members, ids: ids ?? AdminUsageNoticeRecipientsBuilder.ids(members: members, draft: nil),
            refused: refused, emailEnabled: email, locale: Fx.english)
    }

    @Test func theAddedMembersComeFromTheServerUntilADraftTakesOver() throws {
        let all = try members()

        #expect(AdminUsageNoticeRecipientsBuilder.ids(members: all, draft: nil) == [Fx.marcoId])
        #expect(AdminUsageNoticeRecipientsBuilder.ids(members: all, draft: []) == [])
        #expect(AdminUsageNoticeRecipientsBuilder.ids(members: all, draft: [Fx.marcoId, Fx.elenaId]) == [Fx.marcoId, Fx.elenaId])
    }

    @Test func theCardNamesWhoIsAlwaysNotifiedAndWhoIsAddedWithTheirRoles() throws {
        let value = card(try members())

        #expect(value.title == "Usage notices")
        #expect(value.description == "Who else hears your company's usage notices.")
        #expect(value.alwaysTitle == "Always notified")
        #expect(value.alwaysHint == "Owners")
        #expect(value.always.map(\.name) == ["Giulia Ferri"])
        #expect(value.always.map(\.role) == ["Owner"])
        #expect(value.alsoTitle == "Also notify")
        #expect(value.alsoHint == "Members get notices without EUR amounts")
        #expect(value.also.map(\.name) == ["Marco Bianchi"])
        #expect(value.also.map(\.role) == ["Member"])
        #expect(value.also.first?.removeLabel == "Remove Marco Bianchi")
        #expect(value.also.first?.inactiveChip == nil)
        #expect(value.addLabel == "Add a member")
    }

    @Test func noOneElseYet() throws {
        let value = card(try members(), ids: [])

        #expect(value.also.isEmpty)
        #expect(value.alsoEmpty == "No one else yet.")
    }

    @Test func theDeliverySentenceFollowsEmailDelivery() throws {
        let on = card(try members(), email: true)
        let off = card(try members(), email: false)

        #expect(on.delivery == "Notices arrive in the app and by email.")
        #expect(on.deliveryIsEmail)
        #expect(off.delivery == "Notices arrive in the app. Email delivery is coming soon.")
        #expect(!off.deliveryIsEmail)
    }

    @Test func addAMemberListsOnlyThoseNeitherAlwaysNotifiedNorAdded() throws {
        let all = try members()
        let list = AdminUsageNoticeRecipientsBuilder.candidates(members: all, ids: [Fx.marcoId], query: "")

        #expect(list.map(\.name) == ["Elena Rossi"])
        #expect(list.map(\.role) == ["Member"])
        #expect(AdminUsageNoticeRecipientsBuilder.hasCandidates(members: all, ids: [Fx.marcoId]))
    }

    @Test func whenEveryoneIsNotifiedThereIsNobodyToAdd() throws {
        let all = try members()
        let ids = [Fx.marcoId, Fx.elenaId]

        #expect(!AdminUsageNoticeRecipientsBuilder.hasCandidates(members: all, ids: ids))
        #expect(AdminUsageNoticeRecipientsBuilder.candidates(members: all, ids: ids, query: "").isEmpty)
    }

    @Test func theSearchMatchesNameOrEmailWithoutCase() throws {
        let all = try members()
        func found(_ query: String) -> [String] {
            AdminUsageNoticeRecipientsBuilder.candidates(members: all, ids: [Fx.marcoId], query: query).map(\.name)
        }

        #expect(found("ELENA") == ["Elena Rossi"])
        #expect(found("rossi") == ["Elena Rossi"])
        #expect(found("elena@example") == ["Elena Rossi"])
        #expect(found("  ") == ["Elena Rossi"])
        #expect(found("marco").isEmpty)
        #expect(found("zzz").isEmpty)
    }

    @Test func addingAndRemovingSendTheWholeList() throws {
        let all = try members()
        let current = AdminUsageNoticeRecipientsBuilder.ids(members: all, draft: nil)
        let added = current + [Fx.elenaId]
        let removed = added.filter { $0 != Fx.marcoId }

        #expect(added == [Fx.marcoId, Fx.elenaId])
        #expect(removed == [Fx.elenaId])
        #expect(card(all, ids: added).also.map(\.name) == ["Marco Bianchi", "Elena Rossi"])
        #expect(card(all, ids: removed).also.map(\.name) == ["Elena Rossi"])
        #expect(card(all, ids: []).also.isEmpty)
    }

    @Test func aRefusedMemberIsMarkedInactiveWithTheSentence() throws {
        let all = try members()
        let refused = [AdminUsageRefusedPerson(id: Fx.marcoId, name: "Marco Bianchi")]
        let value = card(all, refused: refused)

        #expect(value.also.first?.inactiveChip == "Inactive")
        #expect(value.inactiveNotes == ["Marco Bianchi is no longer an active member and can't receive notices. Remove them to save again."])
    }

    @Test func anIdThatIsNoLongerAMemberReadsFormerMemberInactiveWithItsOldName() throws {
        let all = try members()
        let gone = AdminUsageRefusedPerson(id: "left-the-company", name: "Luca Verdi")
        let value = card(all, ids: [Fx.marcoId, "left-the-company"], refused: [gone])
        let unnamed = card(all, ids: ["left-the-company"], refused: [])

        #expect(value.also.map(\.name) == ["Marco Bianchi", "Luca Verdi"])
        #expect(value.also.last?.inactiveChip == "Inactive")
        #expect(value.inactiveNotes == ["Luca Verdi is no longer an active member and can't receive notices. Remove them to save again."])
        #expect(unnamed.also.first?.name == "Former member")
        #expect(unnamed.also.first?.inactiveChip == "Inactive")
    }

    @Test func aRefusalForSomeoneAlreadyRemovedHasNoSentence() throws {
        let all = try members()
        let refused = [AdminUsageRefusedPerson(id: Fx.marcoId, name: "Marco Bianchi")]
        let value = card(all, ids: [], refused: refused)

        #expect(value.inactiveNotes.isEmpty)
    }

    @Test func theAlwaysNotifiedListPutsOwnersFirst() throws {
        let json = """
        { "user_ids": [], "default_roles": ["owner", "admin"],
          "members": [
            { "user_id": "a", "email": "zed@example.com", "name": "Zed", "role": "admin", "default": true, "added": false },
            { "user_id": "b", "email": "bea@example.com", "name": "Bea", "role": "owner", "default": true, "added": false },
            { "user_id": "c", "email": "abe@example.com", "name": "Abe", "role": "owner", "default": true, "added": false } ] }
        """
        let value = card(try Fx.members(json))

        #expect(value.always.map(\.name) == ["Abe", "Bea", "Zed"])
        #expect(value.always.map(\.role) == ["Owner", "Owner", "Member"])
    }

    @Test func aMemberWithoutANameIsNamedByTheirEmail() throws {
        let json = """
        { "user_ids": ["a"], "default_roles": ["owner"],
          "members": [ { "user_id": "a", "email": "no.name@example.com", "name": "  ", "role": "member", "default": false, "added": true } ] }
        """
        let value = card(try Fx.members(json))

        #expect(value.also.map(\.name) == ["no.name@example.com"])
    }
}
