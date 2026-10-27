//
//  AdminAgentStudioRunEvent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Una riga che un run manda in streaming (POST workflow-runs, GET …/events), per il registro tecnico:
//  si riconoscono i verdetti dei nodi, messaggi ed errori; il resto si mostra come JSON compatto.
//

import Foundation

nonisolated struct AdminAgentStudioRunEvent: Sendable, Identifiable, Hashable {
    let id: Int
    let title: String
    let detail: String?
    let status: String?

    init(index: Int, json: AriaJSON) {
        id = index
        let outer = AdminAgentStudioFields(json)
        // Alcuni eventi portano il contenuto dentro `step`, `data` o `payload`.
        let inner = [outer.object("step"), outer.object("data"), outer.object("payload")].first { !$0.isEmpty }
        let fields = inner ?? outer
        let type = outer.string("type", "event", "kind")
        if let node = fields.string("nodeId"), let outcome = fields.string("outcome") {
            title = fields.string("agentName").map { "\($0) · \(node)" } ?? node
            detail = fields.string("reason")
            status = outcome
        } else if let message = fields.string("message", "error", "detail", "narrative", "text") {
            title = type.map(Self.humanized) ?? String(localized: "Message")
            detail = message
            status = fields.string("status", "outcome") ?? (outer.value("error") != nil ? "error" : nil)
        } else {
            title = type.map(Self.humanized) ?? String(localized: "Event")
            let compact = json.compactDescription
            detail = compact.count > 400 ? String(compact.prefix(400)) + "…" : compact
            status = fields.string("status", "state")
        }
    }

    private static func humanized(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ".", with: " ")
            .capitalized(with: .current)
    }
}
