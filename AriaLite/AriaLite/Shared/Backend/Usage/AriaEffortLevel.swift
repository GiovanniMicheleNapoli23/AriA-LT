//
//  AriaEffortLevel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  I cinque livelli di impegno della chat (base, medium, high, extra, max), nell'ordine in cui la web li elenca.
//  Il moltiplicatore, il blocco e il costo di ogni livello vengono dal server (GET /v1/usage/config).
//

import Foundation

nonisolated enum AriaEffortLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case base, medium, high, extra, max

    /// Il posto nell'elenco: base è il più basso.
    private var rank: Int {
        switch self {
        case .base: 0
        case .medium: 1
        case .high: 2
        case .extra: 3
        case .max: 4
        }
    }

    static func < (lhs: AriaEffortLevel, rhs: AriaEffortLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Chiavi proprie: "Medium"/"High" nel catalogo sono già le priorità ("Media"/"Alta"), qui il livello è maschile.
    var title: String {
        switch self {
        case .base: String(localized: "effort.level.base", defaultValue: "Base")
        case .medium: String(localized: "effort.level.medium", defaultValue: "Medium")
        case .high: String(localized: "effort.level.high", defaultValue: "High")
        case .extra: String(localized: "effort.level.extra", defaultValue: "Extra")
        case .max: String(localized: "effort.level.max", defaultValue: "Max")
        }
    }
}
