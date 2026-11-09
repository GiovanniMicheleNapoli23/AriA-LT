//
//  AdminReportBreakdown.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una ripartizione dei report (per stato, priorità, categoria, tipo): lo schema la dà come oggetto libero,
//  quindi si legge sia come {chiave: numero} sia come lista di {etichetta, numero}.
//

import Foundation

nonisolated struct AdminReportBreakdownItem: Sendable, Hashable, Identifiable {
    let key: String
    let count: Double

    private static let labelKeys = ["label", "name", "key", "status", "priority", "category", "type", "bucket"]

    var id: String { key }
    var label: String { AdminReportFormat.humanized(key) }

    /// Le voci con almeno un elemento, dalla più grande; un valore illeggibile si salta.
    static func parse(_ json: AriaJSON?) -> [AdminReportBreakdownItem] {
        var items: [AdminReportBreakdownItem] = []
        switch json {
        case .object(let object)?:
            for (key, value) in object {
                if let count = AdminReportFormat.number(value) { items.append(.init(key: key, count: count)) }
            }
        case .array(let rows)?:
            for row in rows {
                guard let object = row.objectValue,
                      let key = AdminReportFormat.text(object, keys: Self.labelKeys),
                      let count = AdminReportFormat.number(row) else { continue }
                items.append(.init(key: key, count: count))
            }
        default:
            break
        }
        return items
            .filter { $0.count > 0 }
            .sorted { ($0.count, $1.key) > ($1.count, $0.key) }
    }
}
