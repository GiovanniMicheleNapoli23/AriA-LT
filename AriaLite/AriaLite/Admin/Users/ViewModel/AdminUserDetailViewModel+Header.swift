//
//  AdminUserDetailViewModel+Header.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le righe dell'intestazione della persona (§4): stato, "online" (solo per i titolari) e il carico di lavoro.
//

import Foundation

extension AdminUserDetailViewModel {
    // MARK: - Stato

    var statusText: String { (row?.status ?? .active).listTitle }

    // MARK: - Online

    /// "Online now · …", "Last seen …" o "Not signed in yet": solo per un titolare (§3.2, regola 4).
    var onlineLine: (text: String, isOnline: Bool)? {
        guard viewer.isOwner, let row, !row.isInvitation else { return nil }
        let line = owner.presence(of: row).line
        let text: String
        switch line {
        case .both: text = String(localized: "Online now · web and app")
        case .web: text = String(localized: "Online now · web")
        case .app: text = String(localized: "Online now · app")
        case .lastSeen(let date): text = String(localized: "Last seen \(Self.when(date, now: owner.now))")
        case .never: text = String(localized: "Not signed in yet")
        }
        return (text, line.isOnline)
    }

    /// Un'ora come testo relativo ("2 hours ago", "yesterday"): sta dopo "Last seen", "Signed in", "Used".
    static func when(_ date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .middleOfSentence
        // Un orologio del telefono indietro non deve dare "in 5 seconds".
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }

    // MARK: - Carico

    /// Minuti aperti per una settimana di 40 ore.
    private static let weekMinutes = 40.0 * 60

    /// "{n}h open · {n} overdue · {n}% load", appena GET /v1/members/{id} ha risposto.
    var workloadText: String? {
        guard let workload = details?.workload else { return nil }
        let minutes = Double(workload.openMinutes)
        let hours = ((minutes / 60) * 10).rounded() / 10
        let hoursText = hours.formatted(.number.precision(.fractionLength(0...1)))
        let load = min(150, Int((minutes / Self.weekMinutes * 100).rounded()))
        var parts = [String(localized: "\(hoursText)h open")]
        if workload.overdueCount > 0 { parts.append(workload.overdueText) }
        parts.append(String(localized: "\(load)% load"))
        return parts.joined(separator: " · ")
    }
}
