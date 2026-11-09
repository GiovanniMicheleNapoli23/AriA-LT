//
//  AdminReportTrend.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  L'andamento dei completamenti (completion_trend) come punti per periodo. Lo schema lo dà come oggetto
//  libero: si leggono {mese: numero}, {mese: {serie: numero}} e liste di righe con un campo periodo.
//

import Foundation

nonisolated struct AdminReportTrendPoint: Sendable, Hashable, Identifiable {
    /// Il periodo come arriva dal server (`2026-05`), serve a ordinare.
    let period: String
    let label: String
    /// Vuoto quando c'è una sola serie senza nome.
    let series: String
    let value: Double

    var id: String { "\(period)|\(series)" }

    /// Nome della serie da mostrare: senza nome sono i completati.
    var seriesLabel: String { series.isEmpty ? String(localized: "Completed") : AdminReportFormat.humanized(series) }
}

nonisolated enum AdminReportTrend {
    private static let periodKeys = ["month", "date", "period", "week", "day", "label", "bucket", "x", "key"]

    /// I punti in ordine di tempo.
    static func parse(_ json: AriaJSON?) -> [AdminReportTrendPoint] {
        var rows: [(period: String, values: [String: Double])] = []
        switch json {
        case .object(let object)?:
            for (period, value) in object {
                if let number = AdminReportFormat.number(value), value.objectValue == nil {
                    rows.append((period, ["": number]))
                } else if let nested = value.objectValue {
                    let values = nested.compactMapValues { AdminReportFormat.number($0) }
                    if !values.isEmpty { rows.append((period, values)) }
                }
            }
        case .array(let items)?:
            for (index, item) in items.enumerated() {
                if let number = AdminReportFormat.number(item), item.objectValue == nil {
                    rows.append((String(index + 1), ["": number]))
                } else if let object = item.objectValue {
                    let period = AdminReportFormat.text(object, keys: periodKeys) ?? String(index + 1)
                    var values: [String: Double] = [:]
                    for (key, value) in object where !periodKeys.contains(key) {
                        if let number = AdminReportFormat.number(value), value.objectValue == nil {
                            values[key] = number
                        }
                    }
                    // Un solo numero: serie senza nome (i completati).
                    if values.count == 1, let only = values.values.first { values = ["": only] }
                    if !values.isEmpty { rows.append((period, values)) }
                }
            }
        default:
            break
        }
        let dates = rows.map { date(of: $0.period) }
        let allDated = !dates.isEmpty && dates.allSatisfy { $0 != nil }
        let ordered = rows.enumerated().sorted { lhs, rhs in
            if allDated, let a = dates[lhs.offset], let b = dates[rhs.offset], a != b { return a < b }
            return lhs.element.period.localizedStandardCompare(rhs.element.period) == .orderedAscending
        }.map(\.element)
        return ordered.flatMap { row in
            row.values.sorted { $0.key < $1.key }.map { series, value in
                AdminReportTrendPoint(period: row.period, label: label(for: row.period), series: series, value: value)
            }
        }
    }

    /// `2026-05` o `2026-05-14` (anche con l'ora dopo): il primo giorno del periodo, in UTC.
    private static func date(of period: String) -> Date? {
        let parts = period.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2, parts[0] > 1900, (1...12).contains(parts[1]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts.count > 2 ? parts[2] : 1))
    }

    /// Mese e anno per i periodi mensili, giorno e mese per gli altri; il testo grezzo se non è una data.
    private static func label(for period: String) -> String {
        guard let date = date(of: period) else { return AdminReportFormat.humanized(period) }
        let isMonthly = period.count <= 7
        let style = Date.FormatStyle(timeZone: .gmt)
        return isMonthly
            ? date.formatted(style.month(.abbreviated).year(.twoDigits))
            : date.formatted(style.day().month(.abbreviated))
    }
}
