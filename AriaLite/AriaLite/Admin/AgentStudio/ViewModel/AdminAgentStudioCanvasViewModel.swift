//
//  AdminAgentStudioCanvasViewModel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Il canvas di un workflow, come quello della web: i nodi al loro posto, gli archi tra le uscite,
//  e toccando un nodo le sue opzioni. Sola lettura: il grafo si modifica sulla web.
//  La vista dà la larghezza dei nodi (che segue il Dynamic Type) e l'altezza misurata di ognuno;
//  da qui escono i riquadri dei nodi e le curve degli archi, nello stesso spazio.
//

import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class AdminAgentStudioCanvasViewModel {
    let workflow: AdminAgentStudioWorkflow
    let graph: AdminAgentStudioGraph

    var selectedNodeId: String?
    /// La larghezza di un nodo sullo schermo, a zoom 1.
    private(set) var nodeWidth: CGFloat = AdminAgentStudioCanvasLayout.webNodeWidth
    private(set) var heights: [String: CGFloat] = [:]

    static let defaultNodeHeight: CGFloat = 72

    init(workflow: AdminAgentStudioWorkflow) {
        self.workflow = workflow
        graph = AdminAgentStudioGraph(workflow: workflow)
    }

    var title: String { workflow.name }

    var isEmpty: Bool { graph.isEmpty }

    // MARK: Misure

    func setNodeWidth(_ width: CGFloat) {
        guard width > 0, abs(width - nodeWidth) > 0.5 else { return }
        nodeWidth = width
    }

    func setHeight(_ height: CGFloat, for nodeId: String) {
        guard height > 0, abs((heights[nodeId] ?? 0) - height) > 0.5 else { return }
        heights[nodeId] = height
    }

    var layout: AdminAgentStudioCanvasLayout {
        AdminAgentStudioCanvasLayout(graph: graph, nodeWidth: nodeWidth, heights: heights, defaultHeight: Self.defaultNodeHeight)
    }

    // MARK: Archi

    struct DrawnEdge: Identifiable, Hashable {
        let edge: AdminAgentStudioGraphEdge
        let curve: AdminAgentStudioEdgeCurve
        /// 0xRRGGBB: il colore del nodo da cui parte, quello del loop o il rosso degli errori.
        let colorHex: UInt32
        let isDashed: Bool
        /// Tocca il nodo scelto: più spesso e più scuro.
        let isHighlighted: Bool

        var id: String { edge.id }
    }

    func drawnEdges(in layout: AdminAgentStudioCanvasLayout) -> [DrawnEdge] {
        graph.edges.compactMap { edge in
            guard let curve = layout.curve(for: edge, in: graph) else { return nil }
            let colorHex: UInt32 = switch edge.style {
            case .error: AdminAgentStudioNodeKind.errorColorHex
            case .loopBody, .loopDone, .loopReturn: AdminAgentStudioNodeKind.loopColorHex
            case .normal: graph.node(id: edge.source)?.meta.colorHex ?? 0x8A94A6
            }
            let highlighted = selectedNodeId != nil && (edge.source == selectedNodeId || edge.target == selectedNodeId)
            return DrawnEdge(edge: edge, curve: curve, colorHex: colorHex,
                             isDashed: edge.style == .error || edge.style == .loopReturn, isHighlighted: highlighted)
        }
    }

    // MARK: Selezione

    var selectedNode: AdminAgentStudioGraphNode? { selectedNodeId.flatMap(graph.node(id:)) }

    /// Toccare il nodo già scelto lo deseleziona.
    func select(_ nodeId: String) {
        selectedNodeId = selectedNodeId == nodeId ? nil : nodeId
    }

    func clearSelection() { selectedNodeId = nil }

    var showsInspector: Bool {
        get { selectedNodeId != nil }
        set { if !newValue { selectedNodeId = nil } }
    }

    /// Il testo breve sotto il titolo di un nodo sul canvas.
    func summary(for node: AdminAgentStudioGraphNode) -> String? {
        if node.kind == "trigger" { return AdminAgentStudioNodeOptions.triggerDescription(node.fields.object("trigger")) }
        if node.kind == "loop" {
            let until = node.fields.string("until")
            return until.map { String(localized: "Repeat until \($0)") }
        }
        return node.step.detail
    }

    /// Per un nodo non ancora configurato o di un tipo che l'app non conosce, un avviso al posto del riassunto.
    func warning(for node: AdminAgentStudioGraphNode) -> String? {
        if !node.meta.isKnown { return String(localized: "Made with a newer version of Aria") }
        if summary(for: node) == nil, node.kind != "trigger" { return String(localized: "Not set up yet") }
        return nil
    }

    // MARK: Pannello

    func inspectorSections(for node: AdminAgentStudioGraphNode) -> [AdminAgentStudioNodeOptions.Section] {
        AdminAgentStudioNodeOptions.sections(for: node, in: graph)
    }
}
