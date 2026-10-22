//
//  AdminAgentStudioRunEvent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Le righe che un run manda in streaming (POST workflow-runs, GET …/events): una riga JSON per evento
//  (NDJSON, o SSE con `data:`). Il formato non è documentato: si riconoscono i verdetti dei nodi,
//  messaggi ed errori; il resto si mostra come JSON compatto.
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

/// Il corpo di uno stream, letto per intero.
nonisolated enum AdminAgentStudioRunStream {
    /// Un oggetto per riga; un corpo che è un unico JSON vale come una riga sola (o un array di righe).
    static func lines(from data: Data) -> [AriaJSON] {
        if let whole = try? JSONDecoder().decode(AriaJSON.self, from: data) {
            if case .array(let items) = whole { return items }
            if let object = whole.objectValue, let events = object["events"] ?? object["lines"] {
                return events.arrayValue
            }
            return [whole]
        }
        let text = String(decoding: data, as: UTF8.self)
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            var payload = line.trimmingCharacters(in: .whitespaces)
            // SSE: solo le righe `data:`; `event:`, `id:` e i commenti `:` non portano JSON.
            if payload.hasPrefix("data:") { payload = String(payload.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
            guard payload.hasPrefix("{") || payload.hasPrefix("[") else { return nil }
            return try? JSONDecoder().decode(AriaJSON.self, from: Data(payload.utf8))
        }
    }

    static func events(from lines: [AriaJSON]) -> [AdminAgentStudioRunEvent] {
        lines.enumerated().map { AdminAgentStudioRunEvent(index: $0.offset, json: $0.element) }
    }

    /// L'id del run, dalla prima riga che lo porta.
    static func runId(in lines: [AriaJSON]) -> String? {
        for line in lines {
            let fields = AdminAgentStudioFields(line)
            if let id = fields.string("runId") ?? fields.object("run").string("id", "runId") { return id }
        }
        return nil
    }
}

/// L'esito di un avvio dall'app (controllo, simulazione o run reale): le righe arrivate e l'id del run.
nonisolated struct AdminAgentStudioRunResult: Sendable {
    let mode: AdminAgentStudioRunMode
    let events: [AdminAgentStudioRunEvent]
    let runId: String?
    let finishedAt: Date

    init(mode: AdminAgentStudioRunMode, lines: [AriaJSON]) {
        self.mode = mode
        events = AdminAgentStudioRunStream.events(from: lines)
        runId = AdminAgentStudioRunStream.runId(in: lines)
        finishedAt = .now
    }
}
