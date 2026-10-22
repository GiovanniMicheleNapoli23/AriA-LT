//
//  AdminWorkflowGraph.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il grafo di un flusso: nodi e collegamenti. Si legge in modo tollerante (campi in più o mancanti si
//  ignorano) e si scrive solo con i campi che il server accetta (additionalProperties: false), così il
//  grafo di un modello si può rimandare per creare un flusso. Posizioni e viewport servono solo
//  all'editor della web.
//

import Foundation

nonisolated struct AdminWorkflowGraph: Codable, Sendable, Hashable {
    var nodes: [AdminWorkflowNode] = []
    var edges: [AdminWorkflowEdge] = []

    private enum CodingKeys: String, CodingKey { case nodes, edges }

    init() {}

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nodes = (try? c.decodeIfPresent(AriaLossyArray<AdminWorkflowNode>.self, forKey: .nodes))?.items ?? []
        edges = (try? c.decodeIfPresent(AriaLossyArray<AdminWorkflowEdge>.self, forKey: .edges))?.items ?? []
    }
}

nonisolated struct AdminWorkflowNode: Codable, Sendable, Hashable, Identifiable {
    let id: String
    /// Il tipo (`start`, `agent`, `tools`…), vedi AdminWorkflowNodeKind.
    let kind: String
    let label: String?
    /// Il nome dell'agente, se il server lo manda (lo schema pubblico non lo prevede).
    let agent: String?
    /// Il gruppo che contiene il nodo.
    let parentId: String?
    let x: Double
    let y: Double
    let extent: String?
    let width: Double?
    let height: Double?

    private enum CodingKeys: String, CodingKey { case id, position, data, parentId, extent, width, height, kind, label }
    private enum PositionKeys: String, CodingKey { case x, y }
    private enum DataKeys: String, CodingKey { case kind, label, agent, agentName, agentId }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        let data = try? c.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        func text(_ key: DataKeys) -> String? {
            guard let value = try? data?.decodeIfPresent(String.self, forKey: key) else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        // Un modello può mandare tipo ed etichetta anche fuori da `data`.
        func flat(_ key: CodingKeys) -> String? {
            guard let value = try? c.decodeIfPresent(String.self, forKey: key), !value.isEmpty else { return nil }
            return value
        }
        kind = text(.kind) ?? flat(.kind) ?? "unknown"
        label = text(.label) ?? flat(.label)
        agent = text(.agent) ?? text(.agentName) ?? text(.agentId)
        parentId = (try? c.decodeIfPresent(String.self, forKey: .parentId)).flatMap { $0.isEmpty ? nil : $0 }
        let position = try? c.nestedContainer(keyedBy: PositionKeys.self, forKey: .position)
        x = (try? position?.decodeIfPresent(Double.self, forKey: .x)) ?? 0
        y = (try? position?.decodeIfPresent(Double.self, forKey: .y)) ?? 0
        extent = try? c.decodeIfPresent(String.self, forKey: .extent)
        width = try? c.decodeIfPresent(Double.self, forKey: .width)
        height = try? c.decodeIfPresent(Double.self, forKey: .height)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        var position = c.nestedContainer(keyedBy: PositionKeys.self, forKey: .position)
        try position.encode(x, forKey: .x)
        try position.encode(y, forKey: .y)
        var data = c.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        try data.encode(kind, forKey: .kind)
        try data.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(parentId, forKey: .parentId)
        try c.encodeIfPresent(extent, forKey: .extent)
        try c.encodeIfPresent(width, forKey: .width)
        try c.encodeIfPresent(height, forKey: .height)
    }
}

nonisolated struct AdminWorkflowEdge: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let source: String
    let target: String
    let sourceHandle: String?
    let targetHandle: String?
    /// `default` o `smoothstep`: altri valori il server li rifiuta, quindi non si rimandano.
    let type: String?
    let label: String?

    private enum CodingKeys: String, CodingKey { case id, source, target, sourceHandle, targetHandle, type, label }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(String.self, forKey: .source)
        target = try c.decode(String.self, forKey: .target)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)).flatMap { $0.isEmpty ? nil : $0 }
            ?? "\(source)->\(target)"
        sourceHandle = (try? c.decodeIfPresent(String.self, forKey: .sourceHandle)).flatMap { $0.isEmpty ? nil : $0 }
        targetHandle = (try? c.decodeIfPresent(String.self, forKey: .targetHandle)).flatMap { $0.isEmpty ? nil : $0 }
        let rawType = try? c.decodeIfPresent(String.self, forKey: .type)
        type = ["default", "smoothstep"].contains(rawType ?? "") ? rawType : nil
        label = (try? c.decodeIfPresent(String.self, forKey: .label)).flatMap { $0.isEmpty ? nil : $0 }
    }
}
