//
//  AdminDowntimeStats.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Statistiche di disponibilità degli ultimi 30 giorni (GET /v1/asset-downtime/stats/{asset_tag}).
//  L'OpenAPI non ne descrive la forma: si legge JSON libero, si riconoscono i nomi più probabili
//  e gli altri numeri si mostrano comunque, con la chiave resa leggibile. Niente va perso.
//

import Foundation

nonisolated struct AdminDowntimeStats: Sendable, Equatable {
    /// Percentuale 0…100.
    var uptimePercent: Double?
    var downtimeHours: Double?
    var eventCount: Int?
    var openCount: Int?
    var mttrHours: Double?
    var mtbfHours: Double?
    var periodDays: Int?
    /// I numeri che non riconosciamo, con la chiave resa leggibile.
    var others: [Other] = []

    nonisolated struct Other: Sendable, Hashable {
        let label: String
        let value: Double
    }

    var isEmpty: Bool {
        uptimePercent == nil && downtimeHours == nil && eventCount == nil && openCount == nil
            && mttrHours == nil && mtbfHours == nil && others.isEmpty
    }

    init(json: AriaJSON) {
        // Chiave normalizzata (minuscole, senza `_`): vale sia per `uptime_pct` sia per `uptimePct`.
        var numbers: [String: (key: String, value: Double)] = [:]
        for (key, value) in json.objectValue ?? [:] {
            guard let number = value.doubleValue else { continue }
            numbers[key.lowercased().filter { $0 != "_" }] = (key, number)
        }
        var used: Set<String> = []
        func take(_ names: String...) -> Double? {
            for name in names {
                if let hit = numbers[name] { used.insert(name); return hit.value }
            }
            return nil
        }

        if let uptime = take("uptimepct", "uptimepercent", "uptimepercentage", "uptime", "availabilitypct",
                             "availabilitypercent", "availability") {
            // 0…1 è una frazione, sopra è già una percentuale.
            uptimePercent = uptime <= 1 ? uptime * 100 : uptime
        }
        if let hours = take("totaldowntimehours", "downtimehours", "totalhours") {
            downtimeHours = hours
        } else if let minutes = take("totaldowntimeminutes", "downtimeminutes", "totaldowntimemin", "downtimemin") {
            downtimeHours = minutes / 60
        } else if let seconds = take("totaldowntimeseconds", "downtimeseconds") {
            downtimeHours = seconds / 3600
        }
        eventCount = take("eventcount", "events", "totalevents", "downtimecount", "downtimeevents", "count",
                          "incidents").map { Int($0) }
        openCount = take("opencount", "openevents", "ongoing", "open").map { Int($0) }
        mttrHours = take("mttrhours", "mttr")
        mtbfHours = take("mtbfhours", "mtbf")
        periodDays = take("perioddays", "days", "windowdays").map { Int($0) }

        others = numbers.filter { !used.contains($0.key) }
            .map { Other(label: Self.readable($0.value.key), value: $0.value.value) }
            .sorted { $0.label < $1.label }
    }

    /// `total_events_30d` → "Total events 30d".
    private static func readable(_ key: String) -> String {
        var words: [String] = []
        var current = ""
        for character in key {
            if character == "_" || character == "-" {
                if !current.isEmpty { words.append(current) }
                current = ""
            } else if character.isUppercase, !current.isEmpty {
                words.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { words.append(current) }
        let text = words.joined(separator: " ").lowercased()
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

/// Un riquadro delle statistiche, già formattato.
nonisolated struct AdminStatItem: Sendable, Hashable, Identifiable {
    let title: String
    let value: String
    let systemImage: String
    /// Da guardare: disponibilità bassa, fermi in corso.
    var isWarning = false
    var id: String { title }
}

nonisolated extension AdminDowntimeStats {
    var items: [AdminStatItem] {
        let hours = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        var out: [AdminStatItem] = []
        if let uptimePercent {
            out.append(AdminStatItem(title: String(localized: "Uptime"),
                                     value: (uptimePercent / 100).formatted(.percent.precision(.fractionLength(0...1))),
                                     systemImage: "gauge.with.dots.needle.67percent", isWarning: uptimePercent < 95))
        }
        if let downtimeHours {
            out.append(AdminStatItem(title: String(localized: "Downtime"), value: "\(downtimeHours.formatted(hours)) h",
                                     systemImage: "clock.badge.exclamationmark"))
        }
        if let eventCount {
            out.append(AdminStatItem(title: String(localized: "Events"), value: eventCount.formatted(),
                                     systemImage: "number"))
        }
        if let openCount {
            out.append(AdminStatItem(title: String(localized: "Ongoing"), value: openCount.formatted(),
                                     systemImage: "exclamationmark.octagon", isWarning: openCount > 0))
        }
        if let mttrHours {
            out.append(AdminStatItem(title: String(localized: "MTTR"), value: "\(mttrHours.formatted(hours)) h",
                                     systemImage: "wrench.and.screwdriver"))
        }
        if let mtbfHours {
            out.append(AdminStatItem(title: String(localized: "MTBF"), value: "\(mtbfHours.formatted(hours)) h",
                                     systemImage: "timer"))
        }
        out += others.map {
            AdminStatItem(title: $0.label, value: $0.value.formatted(.number.precision(.fractionLength(0...2))),
                          systemImage: "chart.bar")
        }
        return out
    }
}
