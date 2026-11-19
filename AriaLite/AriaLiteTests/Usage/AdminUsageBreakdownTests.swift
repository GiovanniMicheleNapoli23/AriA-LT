//
//  AdminUsageBreakdownTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Where credits went" (contratto 3.7): le colonne per ruolo, i nomi delle righe (azioni, agenti, persone), la quota
//  con la ripiegatura, "Your usage" di un membro, le descrizioni e la nota del conteggio a dimensione. Più i nomi delle
//  persone: segnaposto mentre i membri si leggono, "Name unavailable", "Former member", "AriA support".
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Usage breakdown")
struct AdminUsageBreakdownTests {
    private let giulia = "6720a1f0c2d94e0012ab34cd"

    private func people(owner: Bool = true, status: AdminUsagePeople.MembersStatus = .loaded,
                        members: [String: String]? = nil, meID: String? = nil, meName: String? = nil) -> AdminUsagePeople {
        AdminUsagePeople(isOwner: owner, membersStatus: status, members: members ?? ["6720a1f0c2d94e0012ab34cd": "Giulia Ferri"],
                         meID: meID, meName: meName)
    }

    private func breakdown(_ board: AriaUsageDashboard? = nil, config: AriaUsageConfig? = nil,
                           people: AdminUsagePeople) throws -> AdminUsageBreakdown {
        AdminUsageBreakdownBuilder.build(try Fx.adminFacts(dashboard: board, config: config), people: people)
    }

    private func column(_ kind: AdminUsageBreakdownColumn.Kind, _ list: AdminUsageBreakdown) throws -> AdminUsageBreakdownColumn {
        try #require(list.columns.first { $0.kind == kind })
    }

    // MARK: Colonne per ruolo

    @Test func anOwnerReadsByActionByUserAndByAgent() throws {
        let list = try breakdown(people: people())

        #expect(list.title == "Where credits went")
        #expect(list.columns.map(\.kind) == [.action, .user, .agent])
        #expect(list.columns.map(\.title) == ["By action", "By user", "By agent"])
        #expect(list.emptyText == "Nothing to show yet.")
        let actions = try column(.action, list)
        #expect(actions.rows.map(\.name) == ["Chat replies", "Diagnostics"])
        #expect(actions.rows.map(\.credits) == ["2,140.5", "874.5"])
        #expect(actions.rows.map(\.fraction) == [0.71, 0.29])
        #expect(actions.foot == nil)
    }

    @Test func byAgentNeedsAnAgentListAndAnEmptyListIsStillAColumn() throws {
        let none = try breakdown(Fx.adminDashboard(top: ["by_agent": NSNull()]), people: people())
        let empty = try breakdown(Fx.adminDashboard(top: ["by_agent": [Any]()]), people: people())

        #expect(none.columns.map(\.kind) == [.action, .user])
        #expect(empty.columns.map(\.kind) == [.action, .user, .agent])
        #expect(try column(.agent, empty).rows.isEmpty)
    }

    @Test func aMemberReadsByActionAndYourUsageWithTheNote() throws {
        let board = try Fx.memberDashboard()
        let list = try breakdown(board, config: Fx.memberAdminConfig(), people: people(owner: false, members: [:], meID: "me-1", meName: "Marco Bianchi"))

        #expect(list.columns.map(\.kind) == [.action, .yours])
        let yours = try column(.yours, list)
        #expect(yours.title == "Your usage")
        #expect(yours.foot == "Owners see every user and agent.")
        #expect(yours.rows.map(\.name) == ["Marco Bianchi (you)"])
        #expect(yours.rows.first?.note == "40% of the company's credits")
        #expect(yours.rows.first?.fraction == 0.4)
    }

    // MARK: Nomi di azioni e agenti

    @Test func anActionNameIsLocalizedAnUnknownKeyIsShownAsSentAndNoKeyIsNotAttributed() throws {
        let board = try Fx.adminDashboard(top: ["by_action_type": [
            ["key": "chat.reply", "credits": "10", "actions": 1, "share": "0.5"],
            ["key": "brand.new.thing", "credits": "5", "actions": 1, "share": "0.25"],
            ["key": NSNull(), "credits": "3", "actions": 1, "share": "0.15"],
            ["credits": "2", "actions": 1, "share": "0.1"],
        ] as [[String: Any]]])
        let rows = try column(.action, breakdown(board, people: people())).rows

        #expect(rows.map(\.name) == ["Chat replies", "brand.new.thing", "Not attributed", "Not attributed"])
        // Due righe senza chiave non hanno lo stesso id.
        #expect(Set(rows.map(\.id)).count == 4)
    }

    @Test func agentRowsNameThePersonaTheWorkflowAndAnyOther() throws {
        let board = try Fx.adminDashboard(top: ["by_agent": [
            ["key": "agent:general", "credits": "10", "share": "0.5"],
            ["key": "agent:predictive", "credits": "5", "share": "0.2"],
            ["key": "agent:order", "credits": "5", "share": "0.1"],
            ["key": "agent:mystery", "credits": "1", "share": "0.1"],
            ["key": "workflow:6b0c11aa90f3d90011ee7701", "label": "Weekly line report", "credits": "1", "share": "0.1"],
        ] as [[String: Any]]])
        let rows = try column(.agent, breakdown(board, people: people())).rows

        #expect(rows.map(\.name) == ["AriA", "Predictive maintenance", "Work orders", "mystery", "Weekly line report"])
    }

    // MARK: Quota

    @Test func aMissingShareFallsBackToTheCreditsOverTheChargedCredits() throws {
        let board = try Fx.adminDashboard(top: ["by_action_type": [
            ["key": "chat.reply", "credits": "301.5", "actions": 1] as [String: Any],
            ["key": "rag.diagnostic", "credits": "0", "actions": 0] as [String: Any],
        ] as [[String: Any]]])
        let rows = try column(.action, breakdown(board, people: people())).rows

        // 301.5 ÷ 3 015.0 = 0.1.
        #expect(rows[0].fraction == 0.1)
        #expect(rows[1].fraction == 0)
    }

    @Test func noChargedCreditsMeansAnEmptyBarNotADivisionByZero() throws {
        let board = try Fx.adminDashboard(period: ["credits_used": "0"], top: ["by_action_type": [
            ["key": "chat.reply", "credits": "5", "actions": 1] as [String: Any],
        ] as [[String: Any]]])
        let rows = try column(.action, breakdown(board, people: people())).rows

        #expect(rows[0].fraction == 0)
    }

    // MARK: Nomi delle persone

    @Test func anOwnerSeesNamesFromTheMembersAndTheirOwnRowAsYou() throws {
        let board = try Fx.adminDashboard(top: ["by_user": [
            ["key": giulia, "credits": "100", "share": "0.4"],
            ["key": "6720a1f0c2d94e0012ab34d2", "credits": "50", "share": "0.2"],
        ] as [[String: Any]]])
        let members = [giulia: "Giulia Ferri", "6720a1f0c2d94e0012ab34d2": "marco@example.com"]
        let rows = try column(.user, breakdown(board, people: people(members: members, meID: giulia, meName: "Giulia Ferri"))).rows

        #expect(rows.map(\.name) == ["Giulia Ferri (you)", "marco@example.com"])
        #expect(rows.allSatisfy { !$0.isPending })
    }

    @Test func whileTheMembersLoadARowIsAPlaceholderNotFormerMember() throws {
        let rows = try column(.user, breakdown(people: people(status: .loading, members: [:]))).rows

        #expect(rows.map(\.isPending) == [true])
        #expect(rows.map(\.name) == [""])
        // Prima della prima richiesta vale lo stesso: nessuno compare come "Former member" per un attimo.
        #expect(try column(.user, breakdown(people: people(status: .notRead, members: [:]))).rows.map(\.isPending) == [true])
    }

    @Test func aFailedMembersListSaysNameUnavailableAndAnUnknownIdIsAFormerMember() throws {
        let failed = try column(.user, breakdown(people: people(status: .failed, members: [:]))).rows
        let former = try column(.user, breakdown(people: people(members: ["someone-else": "Someone"]))).rows

        #expect(failed.map(\.name) == ["Name unavailable"])
        #expect(!failed[0].isPending)
        #expect(former.map(\.name) == ["Former member"])
    }

    @Test func aUserRowWithoutAKeyIsNotAttributed() throws {
        let board = try Fx.adminDashboard(top: ["by_user": [["credits": "3", "actions": 1, "share": "0.1"]] as [[String: Any]]])
        let rows = try column(.user, breakdown(board, people: people())).rows

        #expect(rows.map(\.name) == ["Not attributed"])
    }

    // MARK: Descrizioni

    @Test func theDescriptionNamesTheCycleOrTheClosedMonthForOwnerAndMember() throws {
        let closed = try Fx.adminDashboard(period: ["closed": true, "start": "2026-10-01", "end": "2026-10-31"])
        let memberConfig = try Fx.memberAdminConfig()
        let me = people(owner: false)

        #expect(try breakdown(people: people()).description == "This cycle, by what was done, who did it and which agent ran it.")
        #expect(try breakdown(config: memberConfig, people: me).description == "This cycle, by what was done, and your own usage.")
        #expect(try breakdown(closed, people: people()).description == "In October 2026, by what was done, who did it and which agent ran it.")
        #expect(try breakdown(closed, config: memberConfig, people: me).description == "In October 2026, by what was done, and your own usage.")
    }

    @Test func theCountedBySizeSentenceAppearsOnlyWhenTheCycleIsCountedBySize() throws {
        let bySize = try breakdown(people: people())
        let plain = try breakdown(Fx.adminDashboard(period: ["basis": "credits"]), people: people())

        #expect(bySize.note == "These rows count credits per action: 3,015 in all. Long conversations count by size, so “This cycle” shows 3,832.5.")
        #expect(plain.note == nil)
    }
}

@Suite("Usage people names")
struct AdminUsagePeopleTests {
    private func owner(_ status: AdminUsagePeople.MembersStatus, members: [String: String] = [:]) -> AdminUsagePeople {
        AdminUsagePeople(isOwner: true, membersStatus: status, members: members, meID: "me-1", meName: "Me Myself")
    }

    @Test func aKnownIdHasItsName() {
        #expect(owner(.loaded, members: ["u1": "Ada"]).name(for: "u1") == .name("Ada"))
        // Anche mentre si ricarica: un nome già noto non torna segnaposto.
        #expect(owner(.loading, members: ["u1": "Ada"]).name(for: "u1") == .name("Ada"))
    }

    @Test func theStatesOfAnUnknownId() {
        #expect(owner(.notRead).name(for: "u9") == .loading)
        #expect(owner(.loading).name(for: "u9") == .loading)
        #expect(owner(.failed).name(for: "u9") == .unavailable)
        #expect(owner(.loaded).name(for: "u9") == .formerMember)
        #expect(owner(.loaded).name(for: "u9").text == "Former member")
        #expect(owner(.failed).name(for: "u9").text == "Name unavailable")
        #expect(owner(.loading).name(for: "u9").text == nil)
        #expect(owner(.loading).name(for: "u9").isPending)
    }

    @Test func aNilIdIsTheSupportAgent() {
        #expect(owner(.loaded).name(for: nil) == .supportAgent)
        #expect(owner(.loaded).name(for: nil).text == "AriA support")
        // Anche prima che i membri si siano letti: nessun segnaposto per l'assistenza.
        #expect(owner(.loading).name(for: nil) == .supportAgent)
    }

    @Test func theSignedInPersonHasTheirNameEvenWithoutTheList() {
        let me = owner(.failed)

        #expect(me.name(for: "me-1") == .name("Me Myself"))
        #expect(me.isYou("me-1"))
        #expect(!me.isYou("u9"))
        #expect(!me.isYou(nil))
    }

    @Test func aMemberKnowsOnlyThemselvesAndEveryRowIsTheirs() {
        let member = AdminUsagePeople(isOwner: false, membersStatus: .notRead, members: [:], meID: "me-1", meName: "Me Myself")
        let noName = AdminUsagePeople(isOwner: false, membersStatus: .notRead, members: [:], meID: "me-1", meName: nil)

        #expect(member.isYou("any-id"))
        #expect(member.name(for: "any-id") == .name("Me Myself"))
        // Senza nemmeno il proprio nome non si inventa niente.
        #expect(noName.name(for: "any-id") == .unavailable)
    }
}
