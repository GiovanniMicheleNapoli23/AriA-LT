//
//  AdminUserPresence.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  "Online now" e "Last seen" (§3.2, `lib/users/presence.ts` della web): un'ora sotto i 2 minuti conta come online.
//  Le ore sono UTC in ISO 8601, con o senza frazioni di secondo e con o senza fuso (senza vale UTC): si leggono
//  con tolleranza. Il confronto è con l'orologio del telefono.
//

import Foundation

nonisolated struct AdminUserPresence: Equatable, Sendable {
    static let onlineWindow: TimeInterval = 120

    var web = false
    var app = false
    /// La più recente delle due ore, se ce n'è una.
    var lastSeen: Date?

    var isOnline: Bool { web || app }

    init(web: Bool = false, app: Bool = false, lastSeen: Date? = nil) {
        self.web = web
        self.app = app
        self.lastSeen = lastSeen
    }

    init(_ seen: AdminUserLastSeen?, now: Date) {
        let web = seen?.web.flatMap(Self.date(from:))
        let app = seen?.app.flatMap(Self.date(from:))
        func online(_ date: Date?) -> Bool { date.map { now.timeIntervalSince($0) < Self.onlineWindow } ?? false }
        self.init(web: online(web), app: online(app), lastSeen: [web, app].compactMap(\.self).max())
    }

    /// La riga "online" della persona, solo per i titolari.
    enum Line: Equatable {
        case both
        case web
        case app
        case lastSeen(Date)
        case never

        var isOnline: Bool {
            switch self {
            case .both, .web, .app: true
            case .lastSeen, .never: false
            }
        }
    }

    var line: Line {
        switch (web, app) {
        case (true, true): return .both
        case (true, false): return .web
        case (false, true): return .app
        case (false, false): return lastSeen.map(Line.lastSeen) ?? .never
        }
    }

    // MARK: - Ore

    /// `2026-11-18T13:41:10Z`, `…10.123456+00:00`, `…10.5` (senza fuso = UTC). `nil` se non è un'ora.
    static func date(from text: String) -> Date? {
        let pattern = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(\.\d+)?(Z|z|[+-]\d{2}:?\d{2})?$/
        guard let match = text.trimmingCharacters(in: .whitespaces).wholeMatch(of: pattern) else { return nil }
        var zone = match.4.map(String.init) ?? "Z"
        if zone == "z" { zone = "Z" }
        if zone != "Z", !zone.contains(":") { zone.insert(":", at: zone.index(zone.startIndex, offsetBy: 3)) }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let whole = formatter.date(from: "\(match.1)T\(match.2)\(zone)") else { return nil }
        let fraction = match.3.flatMap { Double("0\($0)") } ?? 0
        return whole.addingTimeInterval(fraction)
    }
}
