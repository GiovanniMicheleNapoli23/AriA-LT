//
//  AdminUsageSpendCapHistoryTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Lo storico del limite (contratto 5.2): la data UTC con l'anno, chi l'ha cambiato (il nome dai membri, "AriA support",
//  "Former member"), il chip "Owner", il limite di prima e quello nuovo (o "—"), i segnaposto finché i membri non sono
//  letti e gli stati vuoto e fallito.
//

import Foundation
import Testing
@testable import AriaLite

private typealias Fx = UsageFixture

@Suite("Spend cap history")
struct AdminUsageSpendCapHistoryTests {
    private func people(_ status: AdminUsagePeople.MembersStatus = .loaded) -> AdminUsagePeople {
        // Prima della lettura (o dopo un errore) l'elenco dei membri è vuoto.
        AdminUsagePeople(isOwner: true, membersStatus: status,
                         members: status == .loaded ? [Fx.giuliaId: "Giulia Ferri"] : [:], meID: nil, meName: nil)
    }

    private func card(_ changes: [AriaSpendCapChange], phase: AdminUsagePhase = .loaded,
                      people: AdminUsagePeople) -> AdminUsageSpendCapHistoryCard {
        AdminUsageSpendCapHistoryBuilder.card(changes: changes, phase: phase, currency: "EUR", locale: Fx.english,
                                              person: { people.name(for: $0) })
    }

    private func rows(_ card: AdminUsageSpendCapHistoryCard) -> [AdminUsageSpendCapHistoryCard.Row] {
        guard case .rows(let rows) = card.content else {
            Issue.record("expected rows, got \(card.content)")
            return []
        }
        return rows
    }

    @Test func theTitlesAndTheColumns() throws {
        let value = card(try Fx.history(), people: people())

        #expect(value.title == "Limit history")
        #expect(value.description == "Every change to the spending limit, newest first.")
        #expect(value.columns == ["Date", "Changed by", "Old limit", "New limit"])
    }

    @Test func aRowShowsTheUTCDayWithItsYearTheNameTheOwnerChipAndTheLimits() throws {
        let first = try #require(rows(card(try Fx.history(), people: people())).first)

        #expect(first.date == "Nov 3, 2026")
        #expect(first.changedBy == "Giulia Ferri")
        #expect(first.ownerChip == "Owner")
        // Il primo limite non ha un limite di prima.
        #expect(first.oldLimit == "—")
        #expect(first.newLimit == "€500")
    }

    @Test func aChangeBySupportReadsAriASupportWithNoChipAndARemovedLimitShowsADash() throws {
        let second = try #require(rows(card(try Fx.history(), people: people())).last)

        #expect(second.changedBy == "AriA support")
        #expect(second.ownerChip == nil)
        #expect(second.date == "Oct 1, 2026")
        #expect(second.oldLimit == "€500")
        #expect(second.newLimit == "—")
    }

    @Test func theDateIsReadInUTCNeverShiftedToLocalTime() throws {
        let json = """
        [ { "effective_from": "2026-11-30T23:59:59Z", "set_by": null, "set_by_role": null, "previous_amount": "1", "amount": "2", "source": "super_admin" } ]
        """
        let row = try #require(rows(card(try Fx.history(json), people: people())).first)

        #expect(row.date == "Nov 30, 2026")
    }

    @Test func aPersonTheMembersDoNotHoldReadsFormerMember() throws {
        let json = """
        [ { "effective_from": "2026-11-03T09:12:44Z", "set_by": "someone-who-left", "set_by_role": "admin",
            "previous_amount": "100", "amount": "200", "source": "tenant" } ]
        """
        let row = try #require(rows(card(try Fx.history(json), people: people())).first)

        #expect(row.changedBy == "Former member")
        // Il chip "Owner" è solo di chi aveva il ruolo di titolare.
        #expect(row.ownerChip == nil)
    }

    @Test func theRowsStayPlaceholdersUntilTheMembersAreRead() throws {
        let changes = try Fx.history()

        #expect(card(changes, people: people(.notRead)).content == .loading)
        #expect(card(changes, people: people(.loading)).content == .loading)
        // Mai "Former member" per un attimo.
        #expect(rows(card(changes, people: people(.loaded))).first?.changedBy == "Giulia Ferri")
    }

    @Test func whenTheMembersFailedTheNameIsUnavailable() throws {
        let value = rows(card(try Fx.history(), people: people(.failed)))

        #expect(value.first?.changedBy == "Name unavailable")
        // "AriA support" non ha bisogno dei membri.
        #expect(value.last?.changedBy == "AriA support")
    }

    @Test func noChangesYetFailedAndLoadingStates() throws {
        #expect(card([], phase: .loaded, people: people()).content == .empty("No changes yet. The limit in force has never been edited."))
        #expect(card([], phase: .failed, people: people()).content == .failed("The limit history could not be loaded. The limit in force still applies."))
        #expect(card([], phase: .loading, people: people()).content == .loading)
        #expect(card([], phase: .idle, people: people()).content == .loading)
    }

    @Test func aRereadKeepsTheRowsInHand() throws {
        let changes = try Fx.history()

        #expect(!rows(card(changes, phase: .loading, people: people())).isEmpty)
        #expect(!rows(card(changes, phase: .failed, people: people())).isEmpty)
    }

    @Test func aRowTheServerSentUnreadableIsDroppedByTheLenientDecoder() throws {
        let json = """
        [ { "effective_from": "2026-11-03T09:12:44Z", "set_by": null, "previous_amount": null, "amount": "500", "source": "tenant" },
          "garbage" ]
        """
        let list = try Fx.decode([AriaLenient<AriaSpendCapChange>].self, json).compactMap(\.value)

        #expect(list.count == 1)
    }
}
