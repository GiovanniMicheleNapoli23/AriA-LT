//
//  AdminWorkOrderTab.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le schede del dettaglio di un ordine, come i pannelli della pagina della web.
//

import Foundation

nonisolated enum AdminWorkOrderTab: String, CaseIterable, Identifiable, Sendable {
    case overview, steps, activity, costs, files

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: String(localized: "Overview")
        case .steps: String(localized: "Steps")
        case .activity: String(localized: "Activity")
        case .costs: String(localized: "Costs")
        case .files: String(localized: "Files")
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "doc.text"
        case .steps: "list.number"
        case .activity: "bubble.left.and.text.bubble.right"
        case .costs: "eurosign.circle"
        case .files: "paperclip"
        }
    }
}
