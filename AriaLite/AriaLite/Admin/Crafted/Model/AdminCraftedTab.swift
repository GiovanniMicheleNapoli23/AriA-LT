//
//  AdminCraftedTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le due metà della pagina Crafted: i widget salvati e le sessioni concluse da cui nascono.
//

import Foundation

nonisolated enum AdminCraftedTab: String, CaseIterable, Identifiable, Sendable {
    case widgets, sessions

    var id: String { rawValue }

    var label: String {
        switch self {
        case .widgets: String(localized: "Widgets")
        case .sessions: String(localized: "Sessions")
        }
    }
}
