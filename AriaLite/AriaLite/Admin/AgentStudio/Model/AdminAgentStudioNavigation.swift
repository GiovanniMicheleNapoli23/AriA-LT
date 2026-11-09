//
//  AdminAgentStudioNavigation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le destinazioni della navigazione di Agent Studio, fatte di soli id, e le voci del gruppo
//  "Configuration" in fondo alla schermata principale.
//

import Foundation

nonisolated enum AdminAgentStudioRoute: Hashable, Sendable {
    case workflow(id: String)
    /// Il grafo del workflow su un canvas, come sulla web.
    case canvas(workflowId: String)
    /// `workflowId` serve per leggere il record del run; un run attivo può non dirlo.
    case run(workflowId: String?, runId: String)
    case approval(id: String)
    /// Lo storico delle approvazioni, con il filtro per stato.
    case approvals
    case policy
    case prompts
    case prompt(name: String)
    case accuracy
}

/// Le voci di "Configuration": ognuna apre una schermata a parte.
nonisolated enum AdminAgentStudioConfigurationItem: CaseIterable, Identifiable, Sendable {
    case approvals, policy, prompts, accuracy

    var id: Self { self }

    var route: AdminAgentStudioRoute {
        switch self {
        case .approvals: .approvals
        case .policy: .policy
        case .prompts: .prompts
        case .accuracy: .accuracy
        }
    }

    var title: String {
        switch self {
        case .approvals: String(localized: "Approvals")
        case .policy: String(localized: "Policy")
        case .prompts: String(localized: "Agent prompts")
        case .accuracy: String(localized: "Agent accuracy")
        }
    }

    var subtitle: String {
        switch self {
        case .approvals: String(localized: "Decisions on steps that waited for a person.")
        case .policy: String(localized: "Limits and rules for every workflow.")
        case .prompts: String(localized: "The system prompt of each agent for this company.")
        case .accuracy: String(localized: "How well each agent's answers were graded.")
        }
    }

    var systemImage: String {
        switch self {
        case .approvals: "person.badge.shield.checkmark"
        case .policy: "shield.lefthalf.filled"
        case .prompts: "text.bubble"
        case .accuracy: "scope"
        }
    }
}
