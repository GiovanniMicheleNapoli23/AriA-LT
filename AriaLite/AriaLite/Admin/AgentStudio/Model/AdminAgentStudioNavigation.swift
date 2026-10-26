//
//  AdminAgentStudioNavigation.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le schede della sezione (come le pagine /agent-studio, /approvals, /policy della web)
//  e le destinazioni della navigazione, fatte di soli id.
//

import Foundation

nonisolated enum AdminAgentStudioTab: String, CaseIterable, Identifiable, Sendable {
    case workflows, approvals, runs, policy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .workflows: String(localized: "Workflows")
        case .approvals: String(localized: "Approvals")
        case .runs: String(localized: "Active")
        case .policy: String(localized: "Policy")
        }
    }
}

nonisolated enum AdminAgentStudioRoute: Hashable, Sendable {
    case workflow(id: String)
    /// Il grafo del workflow su un canvas, come sulla web.
    case canvas(workflowId: String)
    /// `workflowId` serve per leggere il record del run; un run attivo può non dirlo.
    case run(workflowId: String?, runId: String)
    case approval(id: String)
    case prompts
    case prompt(name: String)
}
