//
//  AdminAgentStudioCanvasContent.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Il contenuto del canvas a zoom 1: gli archi (curve di Bézier con freccia), le etichette sugli archi,
//  i nodi alle loro posizioni e i punti di attacco. Lo zoom e lo scorrimento li dà il contenitore.
//

import SwiftUI

struct AdminAgentStudioCanvasContent: View {
    let viewModel: AdminAgentStudioCanvasViewModel

    var body: some View {
        let layout = viewModel.layout
        let edges = viewModel.drawnEdges(in: layout)
        ZStack(alignment: .topLeading) {
            // Un tocco sul vuoto toglie la selezione; i nodi, sopra, prendono i loro tocchi.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { viewModel.clearSelection() }

            Canvas { context, _ in
                for edge in edges { Self.drawEdge(edge, in: &context) }
            }
            .allowsHitTesting(false)

            ForEach(edges) { edge in
                if edge.edge.caption != nil || edge.edge.condition != nil {
                    AdminAgentStudioCanvasEdgeLabel(edge: edge)
                        .position(edge.curve.midpoint)
                        .allowsHitTesting(false)
                }
            }

            ForEach(viewModel.graph.nodes) { node in
                if let frame = layout.frames[node.id] {
                    AdminAgentStudioCanvasNode(node: node, viewModel: viewModel)
                        .frame(width: frame.width)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                            viewModel.setHeight(height, for: node.id)
                        }
                        .offset(x: frame.minX, y: frame.minY)
                }
            }

            // I punti di uscita sopra i nodi, dove gli archi partono (all'arrivo c'è la freccia).
            Canvas { context, _ in
                for edge in edges { Self.drawHandles(of: edge, in: &context) }
            }
            .allowsHitTesting(false)
        }
        .frame(width: layout.contentSize.width, height: layout.contentSize.height, alignment: .topLeading)
    }

    // MARK: Disegno

    private static func drawEdge(_ edge: AdminAgentStudioCanvasViewModel.DrawnEdge, in context: inout GraphicsContext) {
        let curve = edge.curve
        let color = Color(adminAgentStudioHex: edge.colorHex).opacity(edge.isHighlighted ? 0.9 : 0.55)
        var path = Path()
        path.move(to: curve.start)
        path.addCurve(to: curve.end, control1: curve.control1, control2: curve.control2)
        let style = StrokeStyle(lineWidth: edge.isHighlighted ? 2.4 : 1.6, lineCap: .round, lineJoin: .round,
                                dash: edge.isDashed ? [5, 4] : [])
        context.stroke(path, with: .color(color), style: style)

        // La freccia segue la tangente nel punto d'arrivo.
        let angle = atan2(curve.end.y - curve.control2.y, curve.end.x - curve.control2.x)
        let length: CGFloat = 9
        let half: CGFloat = 4.5
        let base = CGPoint(x: curve.end.x - cos(angle) * length, y: curve.end.y - sin(angle) * length)
        var arrow = Path()
        arrow.move(to: curve.end)
        arrow.addLine(to: CGPoint(x: base.x - sin(angle) * half, y: base.y + cos(angle) * half))
        arrow.addLine(to: CGPoint(x: base.x + sin(angle) * half, y: base.y - cos(angle) * half))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }

    private static func drawHandles(of edge: AdminAgentStudioCanvasViewModel.DrawnEdge, in context: inout GraphicsContext) {
        let point = edge.curve.start
        let radius: CGFloat = 4
        let dot = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        context.fill(dot, with: .color(Color.liteSurface))
        context.stroke(dot, with: .color(Color(adminAgentStudioHex: edge.colorHex).opacity(0.85)), lineWidth: 1.5)
    }
}

/// Il nome dell'uscita e la condizione di un arco, in capsule sul punto di mezzo della curva.
private struct AdminAgentStudioCanvasEdgeLabel: View {
    let edge: AdminAgentStudioCanvasViewModel.DrawnEdge

    var body: some View {
        VStack(spacing: 2) {
            if let caption = edge.edge.caption { chip(caption) }
            if let condition = edge.edge.condition { chip(condition) }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.liteSurface, in: Capsule())
            .overlay(Capsule().strokeBorder(Color(adminAgentStudioHex: edge.colorHex).opacity(0.5), lineWidth: 0.75))
    }
}
