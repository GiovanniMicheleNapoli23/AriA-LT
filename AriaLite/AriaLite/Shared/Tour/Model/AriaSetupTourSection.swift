//
//  AriaSetupTourSection.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Le quattro sezioni di "Primi passi con AriA", nell'ordine in cui si presentano: l'intro ne mostra i nomi.
//  Stessi nomi della web (`tour.guide.sections.*`).
//

import Foundation

nonisolated enum AriaSetupTourSection: CaseIterable, Sendable {
    case knowledge, agents, team, marketplace

    var title: LocalizedStringResource {
        switch self {
        case .knowledge: return "Knowledge"
        case .agents: return "Agents"
        case .team: return "Team & users"
        case .marketplace: return "Marketplace"
        }
    }
}
