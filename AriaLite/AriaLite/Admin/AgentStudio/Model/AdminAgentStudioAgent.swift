//
//  AdminAgentStudioAgent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Gli agenti visti da Agent Studio: l'accuratezza recente (agent-accuracy) e il prompt di sistema
//  di ogni agente per l'azienda (agent-prompts: base, override, effettivo).
//

import Foundation

/// L'accuratezza di un agente sulle ultime risposte valutate (AgentAccuracy).
nonisolated struct AdminAgentStudioAgentAccuracy: AdminAgentStudioJSONModel, Identifiable, Hashable {
    static let listKeys = ["agents", "items"]

    let agent: String
    /// 0–100.
    let score: Int
    let graded: Int
    let grounded: Int
    let lastGradedAt: Date?

    var id: String { agent }

    init?(json: AriaJSON) {
        let fields = AdminAgentStudioFields(json)
        guard let agent = fields.string("agent", "name"), let score = fields.int("score") else { return nil }
        self.agent = agent
        self.score = score
        graded = fields.int("graded") ?? 0
        grounded = fields.int("grounded") ?? 0
        lastGradedAt = fields.date("lastGradedAt")
    }
}

/// Il prompt di un agente per l'azienda (AgentPromptView).
nonisolated struct AdminAgentStudioAgentPrompt: AdminAgentStudioJSONModel, Identifiable, Hashable {
    static let listKeys = ["agents", "items"]

    let name: String
    let description: String?
    let basePrompt: String
    let override: String?
    let effectivePrompt: String
    let isOverridden: Bool

    var id: String { name }

    init?(json: AriaJSON) {
        let outer = AdminAgentStudioFields(json)
        let fields = outer.object("agent").isEmpty ? outer : outer.object("agent")
        guard let name = fields.string("name") else { return nil }
        self.name = name
        description = fields.string("description")
        basePrompt = fields.value("basePrompt")?.stringValue ?? ""
        override = fields.string("override")
        effectivePrompt = fields.value("effectivePrompt")?.stringValue ?? override ?? basePrompt
        isOverridden = fields.bool("isOverridden") ?? (override != nil)
    }
}

/// Risposta di PUT agent-prompts/{agent}: il prompt salvato e gli avvisi del server.
nonisolated struct AdminAgentStudioPromptSaved: Decodable, Sendable {
    let prompt: AdminAgentStudioAgentPrompt?
    let warnings: [String]

    init(from decoder: any Decoder) throws {
        let json = try AriaJSON(from: decoder)
        prompt = AdminAgentStudioAgentPrompt(json: json)
        warnings = AdminAgentStudioFields(json).strings("warnings")
    }
}
