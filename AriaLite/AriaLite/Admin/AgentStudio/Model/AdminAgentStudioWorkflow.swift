//
//  AdminAgentStudioWorkflow.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un workflow salvato (StoredWorkflow): nome, attivo sì/no e il grafo di nodi e archi, tenuto così
//  come arriva per rimandarlo a POST workflow-runs. I nodi si leggono in AdminAgentStudioWorkflowStep.
//

import Foundation

nonisolated struct AdminAgentStudioWorkflow: AdminAgentStudioJSONModel, Identifiable {
    static let listKeys = ["workflows", "items"]

    let id: String
    let name: String
    let enabled: Bool
    let description: String?
    let nodes: [AriaJSON]
    let edges: [AriaJSON]
    let createdAt: Date?
    let updatedAt: Date?
    let lastRunAt: Date?
    let runsToday: Int?

    init?(json: AriaJSON) {
        // GET di un workflow può tornarlo avvolto (`{"workflow": {…}}`).
        let outer = AdminAgentStudioFields(json)
        let fields = outer.object("workflow").isEmpty ? outer : outer.object("workflow")
        guard let id = fields.string("id", "workflowId") else { return nil }
        self.id = id
        name = fields.string("name", "title") ?? id
        enabled = fields.bool("enabled", "isEnabled") ?? false
        description = fields.string("description", "summary")
        nodes = fields.array("nodes")
        edges = fields.array("edges")
        createdAt = fields.date("createdAt")
        updatedAt = fields.date("updatedAt")
        lastRunAt = fields.date("lastRunAt")
        runsToday = fields.int("runsToday")
    }

    /// Il grafo come lo vuole POST workflow-runs: nodi e archi intatti, chiavi comprese.
    var graph: AriaJSON {
        .object(["nodes": .array(nodes), "edges": .array(edges)])
    }
}

/// Un nodo del grafo, per la lista dei passi in sola lettura.
nonisolated struct AdminAgentStudioWorkflowStep: Sendable, Identifiable, Hashable {
    let id: String
    let kind: String
    let title: String
    let detail: String?
    let systemImage: String

    init?(json: AriaJSON) {
        let fields = AdminAgentStudioFields(json)
        guard let id = fields.string("id") else { return nil }
        self.id = id
        kind = fields.string("kind", "type") ?? "unknown"
        let label = fields.string("label", "title", "name")
        switch kind {
        case "trigger":
            let trigger = fields.object("trigger", "data")
            title = label ?? String(localized: "Trigger")
            detail = trigger.string("type", "kind", "schedule", "cron", "event")
            systemImage = "bolt.fill"
        case "agent":
            title = fields.string("agentName") ?? label ?? String(localized: "Agent")
            detail = fields.string("task")
            systemImage = "brain"
        case "connector":
            title = fields.string("connectorId") ?? label ?? String(localized: "Connector")
            detail = fields.string("capability")
            systemImage = "point.3.connected.trianglepath.dotted"
        case "action":
            title = label ?? fields.string("actionType") ?? String(localized: "Action")
            detail = label == nil ? nil : fields.string("actionType")
            systemImage = "gearshape"
        case "loop":
            title = label ?? String(localized: "Loop")
            detail = fields.string("until", "stopWhen")
            systemImage = "repeat"
        case "router":
            title = label ?? String(localized: "Router")
            detail = fields.string("mode", "match")
            systemImage = "arrow.triangle.branch"
        case "join":
            title = label ?? String(localized: "Join")
            detail = fields.string("merge", "policy")
            systemImage = "arrow.triangle.merge"
        case "transform":
            title = label ?? String(localized: "Transform")
            detail = fields.string("op")
            systemImage = "wand.and.stars"
        case "subworkflow":
            title = label ?? String(localized: "Sub-workflow")
            detail = fields.string("workflowId")
            systemImage = "square.stack.3d.up"
        case "approval":
            title = label ?? String(localized: "Approval")
            detail = fields.string("instructions", "requiredRole")
            systemImage = "person.badge.shield.checkmark"
        case "orchestrator":
            title = label ?? String(localized: "Orchestrator")
            detail = fields.string("goal")
            systemImage = "circle.hexagongrid"
        case "output":
            title = label ?? String(localized: "Output")
            detail = fields.string("format", "file")
            systemImage = "doc.richtext"
        default:
            title = label ?? kind.replacingOccurrences(of: "_", with: " ").capitalized(with: .current)
            detail = nil
            systemImage = "square.dashed"
        }
    }
}
