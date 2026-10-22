//
//  AdminReasoningNode.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Un nodo del grafo eseguito nel turno, letto da un oggetto libero: nome, durata, esito ed errore
//  dalle chiavi più probabili; tutto il resto resta in righe e blocchi JSON.
//

import Foundation

nonisolated struct AdminReasoningNode: Identifiable, Sendable {
    let id: Int
    let name: String
    let durationMs: Double?
    let status: String?
    let error: String?
    /// La durata rispetto al nodo più lento (0…1), per la barra della cascata.
    var share: Double = 0
    let fields: [AdminAssetField]
    let blocks: [AdminReasoningJSONBlock]

    var durationText: String? { durationMs.map { AdminReasoningFormat.duration(ms: $0) } }
    var hasError: Bool { error != nil }

    private static let nameKeys = ["name", "node", "nodeName", "tool", "toolName", "kind", "type", "id"]
    private static let durationKeys = ["durationMs", "duration_ms", "elapsedMs", "elapsed_ms", "workMs", "latencyMs", "ms"]
    private static let statusKeys = ["status", "outcome", "result"]
    private static let errorKeys = ["error", "errorMessage", "error_message", "exception"]

    init(index: Int, json: AriaJSON) {
        id = index
        let object = json.objectValue ?? [:]
        let nameKey = Self.nameKeys.first { object[$0]?.nonEmptyString != nil }
        name = nameKey.flatMap { object[$0]?.nonEmptyString } ?? json.nonEmptyString
            ?? String(localized: "Node \(index + 1)")
        let durationKey = Self.durationKeys.first { object[$0]?.doubleValue != nil }
        durationMs = durationKey.flatMap { object[$0]?.doubleValue }
        let statusKey = Self.statusKeys.first { object[$0]?.nonEmptyString != nil }
        status = statusKey.flatMap { object[$0]?.nonEmptyString }
        // Un errore può essere un testo o un oggetto ({message, type}).
        let errorKey = Self.errorKeys.first { key in
            guard let value = object[key] else { return false }
            return value.nonEmptyString != nil || value.objectValue?.isEmpty == false
        }
        error = errorKey.flatMap { key in
            object[key]?.nonEmptyString ?? object[key]?["message"]?.nonEmptyString ?? object[key]?.compactDescription
        }
        let shown = Set([nameKey, durationKey, statusKey, errorKey].compactMap(\.self))
        (fields, blocks) = AdminReasoningFormat.split(object, excluding: shown)
    }

    /// I nodi di una trace, con la quota di tempo di ognuno rispetto al più lento.
    static func nodes(of trace: AdminReasoningTrace) -> [AdminReasoningNode] {
        var nodes = trace.nodes.enumerated().map { AdminReasoningNode(index: $0.offset, json: $0.element) }
        let longest = nodes.compactMap(\.durationMs).max() ?? 0
        if longest > 0 {
            for index in nodes.indices { nodes[index].share = (nodes[index].durationMs ?? 0) / longest }
        }
        return nodes
    }
}
