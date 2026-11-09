//
//  AdminAgentStudioGraph.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Il grafo di un workflow come lo disegna il canvas della web (React Flow): nodi alla loro `position`,
//  archi con l'uscita da cui partono (`sourceHandle`). Le uscite e i loro id sono quelli di
//  `sourceHandles` in lib/agent-studio/workflows.ts: un'uscita sola senza id, `body`/`done` per un loop,
//  una per regola più `default` per un router, `error` per un passo con `onError: "route"`.
//  Sola lettura: il grafo si modifica sulla web.
//

import CoreGraphics
import Foundation

nonisolated struct AdminAgentStudioGraph: Sendable {
    let nodes: [AdminAgentStudioGraphNode]
    let edges: [AdminAgentStudioGraphEdge]

    static let loopBodyHandle = "body"
    static let loopDoneHandle = "done"
    static let routerDefaultHandle = "default"
    static let errorHandle = "error"

    init(workflow: AdminAgentStudioWorkflow) {
        let raw = workflow.nodes.compactMap { json -> (AriaJSON, AdminAgentStudioWorkflowStep)? in
            AdminAgentStudioWorkflowStep(json: json).map { (json, $0) }
        }
        var seenNodes = Set<String>()
        let unique = raw.filter { seenNodes.insert($0.1.id).inserted }
        let known = Set(unique.map(\.1.id))

        var parsedEdges: [(id: String, source: String, target: String, handle: String?, condition: AdminAgentStudioFields)] = []
        for (index, json) in workflow.edges.enumerated() {
            let fields = AdminAgentStudioFields(json)
            guard let source = fields.string("source"), let target = fields.string("target"),
                  known.contains(source), known.contains(target) else { continue }
            parsedEdges.append((fields.string("id") ?? "edge-\(index)", source, target,
                                fields.string("sourceHandle"), fields.object("condition")))
        }

        let kinds = Dictionary(unique.map { ($0.1.id, $0.1.kind) }, uniquingKeysWith: { first, _ in first })
        let backEdges = Self.loopBackEdgeIds(kinds: kinds, edges: parsedEdges.map { ($0.id, $0.source, $0.target, $0.handle) })
        let positions = Self.positions(for: unique, edges: parsedEdges.map { ($0.source, $0.target) }, backEdges: backEdges,
                                       edgeIds: parsedEdges.map(\.id))

        nodes = unique.map { json, step in
            let fields = AdminAgentStudioFields(json)
            let edgeHandles = parsedEdges.filter { $0.source == step.id }.compactMap(\.handle)
            return AdminAgentStudioGraphNode(step: step, fields: fields, position: positions[step.id] ?? .zero,
                                             outlets: Self.outlets(kind: step.kind, fields: fields, edgeHandles: edgeHandles))
        }
        let byId = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        edges = parsedEdges.map { edge in
            let source = byId[edge.source]
            let isBack = backEdges.contains(edge.id)
            let style: AdminAgentStudioGraphEdge.Style
            let outletId: String?
            if isBack {
                style = .loopReturn
                outletId = edge.handle
            } else if source?.kind == "loop" {
                // Un arco da un loop senza uscita è di prima delle uscite: vale `done`, come sulla web.
                let isBody = edge.handle == Self.loopBodyHandle
                style = isBody ? .loopBody : .loopDone
                outletId = isBody ? Self.loopBodyHandle : Self.loopDoneHandle
            } else if edge.handle == Self.errorHandle {
                style = .error
                outletId = Self.errorHandle
            } else {
                style = .normal
                outletId = edge.handle
            }
            let outlet = source?.outlet(id: outletId)
            return AdminAgentStudioGraphEdge(
                id: edge.id, source: edge.source, target: edge.target, sourceHandle: outletId, style: style,
                caption: style == .loopReturn ? nil : outlet?.label, condition: Self.conditionText(edge.condition)
            )
        }
    }

    func node(id: String) -> AdminAgentStudioGraphNode? { nodes.first { $0.id == id } }

    var isEmpty: Bool { nodes.isEmpty }

    // MARK: Uscite

    private static func outlets(kind: String, fields: AdminAgentStudioFields, edgeHandles: [String]) -> [AdminAgentStudioGraphOutlet] {
        var outlets: [AdminAgentStudioGraphOutlet] = []
        switch kind {
        case "loop":
            outlets.append(.init(id: loopBodyHandle, role: .body, label: String(localized: "each pass")))
            outlets.append(.init(id: loopDoneHandle, role: .done, label: String(localized: "done")))
        case "router":
            for (index, rule) in fields.array("rules").enumerated() {
                let ruleFields = AdminAgentStudioFields(rule)
                guard let id = ruleFields.string("id") else { continue }
                outlets.append(.init(id: id, role: .rule, label: ruleFields.string("label") ?? String(localized: "rule \(index + 1)")))
            }
            outlets.append(.init(id: routerDefaultHandle, role: .defaultBranch, label: String(localized: "otherwise")))
        default:
            outlets.append(.init(id: nil, role: .out, label: nil))
        }
        if kind != "trigger", fields.string("onError") == "route" {
            outlets.append(.init(id: errorHandle, role: .error, label: String(localized: "on error")))
        }
        // Un nodo di un tipo che l'app non conosce: le sue uscite sono quelle che i suoi archi nominano.
        if !AdminAgentStudioNodeKind.isKnown(kind) {
            for handle in edgeHandles where !outlets.contains(where: { $0.id == handle }) {
                outlets.append(.init(id: handle, role: .other, label: handle))
            }
        }
        return outlets
    }

    // MARK: Loop

    /// Gli archi che chiudono un loop: da un passo del suo corpo di nuovo al loop. Si disegnano tratteggiati
    /// e non contano per l'impaginazione, se no ogni loop sarebbe una catena infinita.
    private static func loopBackEdgeIds(kinds: [String: String],
                                        edges: [(id: String, source: String, target: String, handle: String?)]) -> Set<String> {
        var outgoing: [String: [String]] = [:]
        for edge in edges { outgoing[edge.source, default: []].append(edge.target) }
        var back = Set<String>()
        for (loopId, kind) in kinds where kind == "loop" {
            let entries = edges.filter { $0.source == loopId && $0.handle == loopBodyHandle && $0.target != loopId }.map(\.target)
            var body = Set(entries)
            var queue = entries
            while !queue.isEmpty {
                let id = queue.removeFirst()
                for next in outgoing[id] ?? [] where next != loopId && !body.contains(next) {
                    body.insert(next)
                    queue.append(next)
                }
            }
            for edge in edges where edge.target == loopId && body.contains(edge.source) { back.insert(edge.id) }
        }
        return back
    }

    // MARK: Posizioni

    /// Le posizioni salvate dalla web. Se mancano tutte (grafo fatto fuori dal canvas) i nodi si mettono
    /// a colonne per profondità dal trigger, come li impagina la web.
    private static func positions(for nodes: [(AriaJSON, AdminAgentStudioWorkflowStep)], edges: [(source: String, target: String)],
                                  backEdges: Set<String>, edgeIds: [String]) -> [String: CGPoint] {
        var saved: [String: CGPoint] = [:]
        for (json, step) in nodes {
            let position = AdminAgentStudioFields(json).object("position")
            if let x = position.double("x"), let y = position.double("y") { saved[step.id] = CGPoint(x: x, y: y) }
        }
        let distinct = Set(saved.values.map { "\($0.x),\($0.y)" })
        if saved.count == nodes.count, distinct.count > 1 || nodes.count <= 1 { return saved }

        let forward = zip(edgeIds, edges).filter { !backEdges.contains($0.0) }.map(\.1)
        let ids = nodes.map(\.1.id)
        var depth = Dictionary(ids.map { ($0, 0) }, uniquingKeysWith: { first, _ in first })
        // Bellman-Ford sul grafo senza ritorni: al più n giri, così un ciclo rimasto non blocca.
        for _ in 0..<ids.count {
            var changed = false
            for edge in forward where (depth[edge.source] ?? 0) + 1 > (depth[edge.target] ?? 0) {
                depth[edge.target] = min((depth[edge.source] ?? 0) + 1, ids.count)
                changed = true
            }
            if !changed { break }
        }
        var rowInColumn: [Int: Int] = [:]
        var result: [String: CGPoint] = [:]
        for id in ids {
            let column = depth[id] ?? 0
            let row = rowInColumn[column, default: 0]
            rowInColumn[column] = row + 1
            result[id] = CGPoint(x: Double(column) * 300, y: Double(row) * 160)
        }
        return result
    }

    // MARK: Condizioni

    /// Una condizione d'arco in parole; nessuna se passa sempre.
    private static func conditionText(_ fields: AdminAgentStudioFields) -> String? {
        guard !fields.isEmpty else { return nil }
        let kind = fields.string("kind") ?? "always"
        let outcomes = fields.strings("outcomes")
        switch kind {
        case "always":
            return nil
        case "outcome" where !outcomes.isEmpty:
            return String(localized: "When: \(outcomes.joined(separator: ", "))")
        default:
            if let expr = fields.value("expr"), expr != .null { return "\(kind): \(expr.compactDescription)" }
            return outcomes.isEmpty ? kind : "\(kind): \(outcomes.joined(separator: ", "))"
        }
    }
}

/// Un nodo del canvas. `position` è in pixel della web (nodi larghi 220).
nonisolated struct AdminAgentStudioGraphNode: Sendable, Identifiable, Hashable {
    let step: AdminAgentStudioWorkflowStep
    /// Il nodo intero, per il pannello delle opzioni.
    let fields: AdminAgentStudioFields
    let position: CGPoint
    let outlets: [AdminAgentStudioGraphOutlet]

    var id: String { step.id }
    var kind: String { step.kind }
    var meta: AdminAgentStudioNodeKind { AdminAgentStudioNodeKind(kind) }

    func outlet(id: String?) -> AdminAgentStudioGraphOutlet? { outlets.first { $0.id == id } }

    /// Le uscite con un nome, elencate sotto il titolo (le regole di un router, "on error").
    var labelledOutlets: [AdminAgentStudioGraphOutlet] { outlets.filter { $0.label != nil && kind != "loop" } }
}

nonisolated struct AdminAgentStudioGraphOutlet: Sendable, Hashable {
    enum Role: Sendable, Hashable { case out, body, done, rule, defaultBranch, error, other }

    /// Il `sourceHandle` degli archi che escono da qui; `nil` per l'unica uscita normale.
    let id: String?
    let role: Role
    let label: String?
}

nonisolated struct AdminAgentStudioGraphEdge: Sendable, Identifiable, Hashable {
    enum Style: Sendable, Hashable {
        case normal
        /// Da un passo con `onError: "route"`: tratteggiato rosso.
        case error
        /// Dal loop ai passi che ripete ("each pass").
        case loopBody
        /// Dal loop a ciò che viene dopo ("done").
        case loopDone
        /// Dal corpo di nuovo al loop: tratteggiato nel colore del loop.
        case loopReturn
    }

    let id: String
    let source: String
    let target: String
    /// L'uscita del nodo di partenza, già risolta (per un loop sempre `body` o `done`).
    let sourceHandle: String?
    let style: Style
    /// Il nome dell'uscita, scritto accanto all'arco.
    let caption: String?
    /// La condizione dell'arco in parole, se non passa sempre.
    let condition: String?
}

/// Nome e colore di ogni tipo di nodo, da `NODE_KIND_META` della web.
nonisolated struct AdminAgentStudioNodeKind: Sendable, Hashable {
    let kind: String

    init(_ kind: String) { self.kind = kind }

    static let known = ["trigger", "connector", "agent", "action", "loop", "router", "join", "transform",
                        "subworkflow", "approval", "orchestrator", "output"]

    static func isKnown(_ kind: String) -> Bool { known.contains(kind) }

    var isKnown: Bool { Self.isKnown(kind) }

    var label: String {
        switch kind {
        case "trigger": String(localized: "Trigger")
        case "connector": String(localized: "Connector")
        case "agent": String(localized: "Agent")
        case "action": String(localized: "Action")
        case "loop": String(localized: "Loop")
        case "router": String(localized: "Router")
        case "join": String(localized: "Join")
        case "transform": String(localized: "Transform")
        case "subworkflow": String(localized: "Sub-workflow")
        case "approval": String(localized: "Approval")
        case "orchestrator": String(localized: "Orchestrator")
        case "output": String(localized: "Output")
        default: kind.replacingOccurrences(of: "_", with: " ").capitalized(with: .current)
        }
    }

    /// Il colore del tipo come 0xRRGGBB, lo stesso in chiaro e in scuro (come sulla web).
    var colorHex: UInt32 {
        switch kind {
        case "trigger": 0x3E80A3
        case "connector": 0x2B45CA
        case "agent": 0x433EA3
        case "action": 0x64748B
        case "loop": Self.loopColorHex
        case "router": 0x2F7D95
        case "join": 0x3B8B6E
        case "transform": 0x7A6F2A
        case "subworkflow": 0x5A6B8C
        case "approval": 0xC0553A
        case "orchestrator": 0x7C4DBB
        case "output": 0x2E8A57
        default: 0x8A94A6
        }
    }

    static let loopColorHex: UInt32 = 0xB4588F
    static let errorColorHex: UInt32 = 0xC0553A
}
