//
//  AdminAgentStudioCanvasLayout.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Dove sta ogni nodo sul canvas e da dove a dove va ogni arco. Le posizioni della web sono in pixel per
//  nodi larghi 220: qui si scalano sulla larghezza vera del nodo (che cresce col Dynamic Type), così la
//  forma del grafo resta quella della web anche col testo grande.
//  Gli attacchi sono quelli dei nodi della web (workflow-flow.tsx): entrata a sinistra, uscita a destra;
//  "on error" in basso per i passi classici; un loop esce in basso per "each pass" (35%), riceve il
//  ritorno in basso (65%) ed esce a destra per "done"; i nodi v2 hanno tutte le uscite a destra, in fila.
//

import CoreGraphics

nonisolated struct AdminAgentStudioCanvasLayout: Sendable {
    /// La larghezza dei nodi della web, a cui si riferiscono le posizioni salvate.
    static let webNodeWidth: CGFloat = 220
    static let margin: CGFloat = 60
    /// Spazio sotto l'ultimo nodo: i ritorni dei loop scendono sotto i nodi.
    static let bottomMargin: CGFloat = 120

    let frames: [String: CGRect]
    let contentSize: CGSize

    /// `heights` sono quelle misurate; finché un nodo non è misurato vale `defaultHeight`.
    init(graph: AdminAgentStudioGraph, nodeWidth: CGFloat, heights: [String: CGFloat], defaultHeight: CGFloat) {
        let scale = nodeWidth / Self.webNodeWidth
        let minX = graph.nodes.map(\.position.x).min() ?? 0
        let minY = graph.nodes.map(\.position.y).min() ?? 0
        var frames: [String: CGRect] = [:]
        for node in graph.nodes {
            let origin = CGPoint(x: (node.position.x - minX) * scale + Self.margin,
                                 y: (node.position.y - minY) * scale + Self.margin)
            frames[node.id] = CGRect(origin: origin, size: CGSize(width: nodeWidth, height: heights[node.id] ?? defaultHeight))
        }
        self.frames = frames
        let maxX = frames.values.map(\.maxX).max() ?? 0
        let maxY = frames.values.map(\.maxY).max() ?? 0
        contentSize = CGSize(width: maxX + Self.margin, height: maxY + Self.bottomMargin)
    }

    func frame(of nodeId: String) -> CGRect? { frames[nodeId] }

    // MARK: Archi

    func curve(for edge: AdminAgentStudioGraphEdge, in graph: AdminAgentStudioGraph) -> AdminAgentStudioEdgeCurve? {
        guard let sourceFrame = frames[edge.source], let targetFrame = frames[edge.target],
              let source = graph.node(id: edge.source) else { return nil }
        let start = outletAnchor(of: source, frame: sourceFrame, handle: edge.sourceHandle)
        let end: Anchor = edge.style == .loopReturn
            ? Anchor(point: CGPoint(x: targetFrame.minX + targetFrame.width * 0.65, y: targetFrame.maxY), direction: CGVector(dx: 0, dy: 1))
            : Anchor(point: CGPoint(x: targetFrame.minX, y: targetFrame.midY), direction: CGVector(dx: -1, dy: 0))
        let distance = hypot(end.point.x - start.point.x, end.point.y - start.point.y)
        // Un ritorno parte e arriva in basso: la curva scende sotto i nodi e risale.
        let reach = edge.style == .loopReturn ? max(60, distance * 0.35) : min(200, max(48, distance * 0.5))
        return AdminAgentStudioEdgeCurve(
            start: start.point,
            control1: CGPoint(x: start.point.x + start.direction.dx * reach, y: start.point.y + start.direction.dy * reach),
            control2: CGPoint(x: end.point.x + end.direction.dx * reach, y: end.point.y + end.direction.dy * reach),
            end: end.point
        )
    }

    private struct Anchor {
        let point: CGPoint
        /// Verso dove esce la curva dall'attacco.
        let direction: CGVector
    }

    private static let classicKinds: Set<String> = ["trigger", "connector", "agent", "action"]

    private func outletAnchor(of node: AdminAgentStudioGraphNode, frame: CGRect, handle: String?) -> Anchor {
        let right = CGVector(dx: 1, dy: 0)
        let down = CGVector(dx: 0, dy: 1)
        func bottom(_ fraction: CGFloat) -> Anchor {
            Anchor(point: CGPoint(x: frame.minX + frame.width * fraction, y: frame.maxY), direction: down)
        }
        let rightCenter = Anchor(point: CGPoint(x: frame.maxX, y: frame.midY), direction: right)

        if node.kind == "loop" {
            switch handle {
            case AdminAgentStudioGraph.loopBodyHandle: return bottom(0.35)
            case AdminAgentStudioGraph.errorHandle: return bottom(0.88)
            default: return rightCenter
            }
        }
        if Self.classicKinds.contains(node.kind) {
            return handle == AdminAgentStudioGraph.errorHandle ? bottom(0.5) : rightCenter
        }
        // Nodi v2 e sconosciuti: le uscite in fila sul lato destro, nell'ordine di `outlets`.
        let outlets = node.outlets
        guard let index = outlets.firstIndex(where: { $0.id == handle }) ?? outlets.firstIndex(where: { $0.role == .out }) else {
            return rightCenter
        }
        let y = frame.minY + frame.height * CGFloat(index + 1) / CGFloat(outlets.count + 1)
        return Anchor(point: CGPoint(x: frame.maxX, y: y), direction: right)
    }
}

/// Una curva di Bézier cubica tra due attacchi, nello spazio del canvas.
nonisolated struct AdminAgentStudioEdgeCurve: Sendable, Hashable {
    let start: CGPoint
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint

    /// Il punto della curva a metà (t = 0.5), dove va scritta l'etichetta dell'arco.
    var midpoint: CGPoint {
        CGPoint(x: 0.125 * start.x + 0.375 * control1.x + 0.375 * control2.x + 0.125 * end.x,
                y: 0.125 * start.y + 0.375 * control1.y + 0.375 * control2.y + 0.125 * end.y)
    }
}
