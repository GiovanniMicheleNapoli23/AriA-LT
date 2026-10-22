//
//  AdminMaintenanceFormat.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Come si scrivono date, intervalli e durate dei piani di manutenzione nelle schermate admin.
//

import Foundation

enum AdminMaintenanceFormat {
    /// "22 ott 2026".
    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// "Tra 3 giorni", "2 giorni fa": solo per la prossima scadenza.
    static func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }

    /// "1 h 30 min".
    static func duration(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// "Every 500 h" per un piano a ore.
    static func hours(_ hours: Double) -> String {
        String(localized: "Every \(hours.formatted(.number.precision(.fractionLength(0...2)))) h")
    }

    /// ISO-8601 con frazioni, come lo vuole il backend.
    static func wireString(_ date: Date) -> String {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(date)
    }

    /// Due date uguali al secondo: il server le tiene al secondo e il selettore no.
    static func sameSecond(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (x?, y?): Int(x.timeIntervalSince1970) == Int(y.timeIntervalSince1970)
        default: false
        }
    }

    /// "Frequenza" in una riga: "Monthly · every 500 h".
    static func schedule(_ plan: AdminMaintenancePlan) -> String {
        var parts = [AdminMaintenanceFrequency.label(for: plan.frequency)]
        if let hours = plan.frequencyHours, hours > 0 { parts.append(Self.hours(hours).lowercased()) }
        return parts.joined(separator: " · ")
    }

    /// Elementi non vuoti uniti da " · ".
    static func joined(_ parts: [String?]) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
