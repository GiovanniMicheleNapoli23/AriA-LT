//
//  ChatHistoryGroupsTests.swift
//  AriaLiteTests
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I gruppi per data dello storico delle chat: oggi, ieri, ultima settimana, più vecchie
//  (anche quelle senza data), nell'ordine giusto e senza gruppi vuoti.
//

import Foundation
import Testing
@testable import AriaLite

@MainActor
struct ChatHistoryGroupsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }

    /// Mercoledì 22 ottobre 2026, 15:00 a Roma.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 15))!
    }

    private func session(_ id: String, hoursAgo: Double?) -> AriaSessionSummary {
        let date = hoursAgo.map { ISO8601DateFormatter().string(from: now.addingTimeInterval(-$0 * 3600)) }
        return AriaSessionSummary(sessionId: id, title: id, status: nil, createdAt: nil, lastActivityAt: date)
    }

    @Test("Ogni conversazione nel suo gruppo, dal più recente")
    func groupsByDay() {
        let sessions = [
            session("this-morning", hoursAgo: 5),
            session("last-night", hoursAgo: 17),
            session("monday", hoursAgo: 50),
            session("last-month", hoursAgo: 24 * 30),
            session("undated", hoursAgo: nil),
        ]
        let groups = AriaChatHistoryViewModel.groups(sessions, now: now, calendar: calendar)
        #expect(groups.map(\.period) == [.today, .yesterday, .lastWeek, .older])
        #expect(groups[0].sessions.map(\.sessionId) == ["this-morning"])
        #expect(groups[1].sessions.map(\.sessionId) == ["last-night"])
        #expect(groups[2].sessions.map(\.sessionId) == ["monday"])
        #expect(groups[3].sessions.map(\.sessionId) == ["last-month", "undated"])
    }

    @Test("I gruppi vuoti non si mostrano")
    func skipsEmptyGroups() {
        let groups = AriaChatHistoryViewModel.groups([session("old", hoursAgo: 24 * 20)], now: now, calendar: calendar)
        #expect(groups.map(\.period) == [.older])
    }
}
