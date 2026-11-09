//
//  AdminLLMUsagePeriod.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I periodi del selettore (7, 30, 90 giorni): dalla data scelta a adesso.
//

import Foundation

enum AdminLLMUsagePeriod: CaseIterable, Identifiable, Equatable {
    case days7
    case days30
    case days90

    var id: Self { self }

    var days: Int {
        switch self {
        case .days7: 7
        case .days30: 30
        case .days90: 90
        }
    }

    var label: String {
        switch self {
        case .days7: String(localized: "7 days")
        case .days30: String(localized: "30 days")
        case .days90: String(localized: "90 days")
        }
    }

    /// Intervallo da `now` indietro di `days` giorni, fino a `now`.
    func range(endingAt now: Date) -> (from: Date, to: Date) {
        (now.addingTimeInterval(-Double(days) * 86_400), now)
    }
}
