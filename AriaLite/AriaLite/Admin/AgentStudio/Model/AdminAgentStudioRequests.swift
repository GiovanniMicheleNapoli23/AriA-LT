//
//  AdminAgentStudioRequests.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  I body delle scritture di Agent Studio. Le chiavi sono scritte a mano: questa API mescola
//  snake_case (richiesta di run) e camelCase (grafo, policy), quindi niente conversione automatica.
//

import Foundation

/// PUT workflows/{id}/enabled.
nonisolated struct AdminAgentStudioEnableBody: Encodable, Sendable {
    let enabled: Bool
}

/// POST workflow-runs: controlla, simula o esegue un workflow salvato.
/// Il grafo va con le sue chiavi originali (camelCase), per questo non si converte nulla.
nonisolated struct AdminAgentStudioRunBody: Encodable, Sendable {
    let workflowId: String
    let workflowName: String
    let mode: String
    let graph: AriaJSON
    let plantId: String?

    enum CodingKeys: String, CodingKey {
        case workflowId = "workflow_id"
        case workflowName = "workflow_name"
        case mode, graph
        case plantId = "plant_id"
    }
}

/// POST approvals/{id}/decision.
nonisolated struct AdminAgentStudioDecisionBody: Encodable, Sendable {
    let decision: String
    let comment: String
}

/// PUT agent-prompts/{agent}.
nonisolated struct AdminAgentStudioPromptBody: Encodable, Sendable {
    let prompt: String
}

/// Le tre modalità di POST workflow-runs.
nonisolated enum AdminAgentStudioRunMode: String, CaseIterable, Identifiable, Sendable {
    /// Verifica connettori e policy senza eseguire nulla.
    case check
    /// Esegue gli agenti ma simula gli effetti esterni.
    case simulate
    /// Run reale: le azioni vanno davvero ai sistemi collegati.
    case run

    var id: String { rawValue }

    var label: String {
        switch self {
        case .check: String(localized: "Check")
        case .simulate: String(localized: "Simulate")
        case .run: String(localized: "Run for real")
        }
    }

    /// Una frase che dice cosa succede davvero scegliendo questa modalità.
    var explanation: String {
        switch self {
        case .check: String(localized: "Tests connectors and policies. No agent runs, nothing is changed.")
        case .simulate: String(localized: "Agents really work on your data, but actions on external systems are only simulated.")
        case .run: String(localized: "Agents run and their actions reach the connected systems. Steps that need approval wait for a person.")
        }
    }

    var systemImage: String {
        switch self {
        case .check: "checklist"
        case .simulate: "theatermasks"
        case .run: "play.fill"
        }
    }
}
