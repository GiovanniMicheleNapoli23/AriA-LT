//
//  AdminWorkflowOutline.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Il grafo di un flusso raccontato come una lista: i passi nell'ordine in cui il flusso li percorre
//  (dal nodo di partenza, seguendo i collegamenti) e, per ognuno, dove va dopo ("A → B").
//  Sul telefono non c'è un editor del grafo: questa è la lettura.
//

import Foundation

nonisolated struct AdminWorkflowStep: Identifiable, Sendable, Hashable {
    nonisolated struct Connection: Identifiable, Sendable, Hashable {
        let id: String
        let targetTitle: String
        /// L'etichetta del collegamento (es. il ramo "sì"/"no").
        let label: String?
    }

    let id: String
    let title: String
    let kindLabel: String
    let systemImage: String
    /// L'agente, quando il titolo è un'altra etichetta.
    let detail: String?
    /// Il gruppo che contiene il passo.
    let groupTitle: String?
    /// Il tipo non è disponibile su questo server.
    let isUnavailable: Bool
    let connections: [Connection]
}

nonisolated enum AdminWorkflowOutline {
    /// `unavailableKinds`: i tipi che node-kinds dice non disponibili (può essere vuoto se la rotta non risponde).
    static func steps(of graph: AdminWorkflowGraph, unavailableKinds: Set<String> = []) -> [AdminWorkflowStep] {
        let titles = Dictionary(graph.nodes.map { ($0.id, title(of: $0)) }) { first, _ in first }
        return ordered(graph).map { node in
            let nodeTitle = titles[node.id] ?? node.id
            let connections = graph.edges.filter { $0.source == node.id }.map {
                AdminWorkflowStep.Connection(id: $0.id, targetTitle: titles[$0.target] ?? $0.target, label: $0.label)
            }
            return AdminWorkflowStep(
                id: node.id, title: nodeTitle, kindLabel: AdminWorkflowNodeKind.label(for: node.kind),
                systemImage: AdminWorkflowNodeKind.systemImage(for: node.kind),
                detail: node.label != nil && node.agent != nil && node.agent != nodeTitle ? node.agent : nil,
                groupTitle: node.parentId.flatMap { titles[$0] ?? $0 },
                isUnavailable: unavailableKinds.contains(node.kind), connections: connections)
        }
    }

    private static func title(of node: AdminWorkflowNode) -> String {
        node.label ?? node.agent ?? AdminWorkflowNodeKind.label(for: node.kind)
    }

    /// In ampiezza dai nodi di partenza (tipo `start`, o senza collegamenti in ingresso); i nodi
    /// non raggiunti (isolati, o in un ciclo senza ingresso) si accodano nell'ordine del server.
    private static func ordered(_ graph: AdminWorkflowGraph) -> [AdminWorkflowNode] {
        let byId = Dictionary(graph.nodes.map { ($0.id, $0) }) { first, _ in first }
        let targets = Set(graph.edges.map(\.target))
        var queue = graph.nodes.filter { $0.kind == AdminWorkflowNodeKind.start.rawValue }
        if queue.isEmpty { queue = graph.nodes.filter { !targets.contains($0.id) } }
        var seen = Set<String>()
        var result: [AdminWorkflowNode] = []
        var index = 0
        while index < queue.count {
            let node = queue[index]
            index += 1
            guard seen.insert(node.id).inserted else { continue }
            result.append(node)
            queue += graph.edges.filter { $0.source == node.id }.compactMap { byId[$0.target] }
        }
        return result + graph.nodes.filter { !seen.contains($0.id) }
    }
}
