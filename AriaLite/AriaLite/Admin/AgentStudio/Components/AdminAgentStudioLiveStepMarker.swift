//
//  AdminAgentStudioLiveStepMarker.swift
//  AriaLite
//
//  Created by Giovanni Michele on 27/10/26.
//
//  Il segno di un passo nella linea del run: numero, ruota di avanzamento, spunta o simbolo di blocco.
//

import SwiftUI

struct AdminAgentStudioLiveStepMarker: View {
    let state: AdminAgentStudioLiveStepRow.State
    let index: Int
    let side: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .overlay { Circle().strokeBorder(Color.secondary.opacity(0.5), lineWidth: state == .waiting ? 1.5 : 0) }
            switch state {
            case .waiting:
                Text("\(index)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
            case .running:
                ProgressView()
                    .controlSize(.mini)
                    .tint(Color.liteOnAccent)
            default:
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: side, height: side)
        .animation(.snappy, value: state)
    }

    private var fill: Color {
        switch state {
        case .waiting: .clear
        case .running: Color.liteAccent
        default: tint.opacity(0.16)
        }
    }

    private var tint: Color {
        switch state {
        case .ran, .simulated: .green
        case .needsApproval: .orange
        case .blocked, .failed: .red
        case .unconfigured: .yellow
        case .skipped, .waiting: .secondary
        case .running: Color.liteAccent
        }
    }

    private var symbol: String {
        switch state {
        case .ran, .simulated: "checkmark"
        case .needsApproval: "hand.raised"
        case .blocked: "xmark.octagon"
        case .unconfigured: "exclamationmark.triangle"
        case .skipped: "arrow.turn.down.right"
        case .failed: "xmark.circle"
        case .waiting, .running: "circle"
        }
    }
}

/// La linea tra due passi: piena per quelli conclusi, tratteggiata per quelli che devono ancora venire.
struct AdminAgentStudioStepConnector: View {
    let isSolid: Bool

    var body: some View {
        ConnectorLine()
            .stroke(isSolid ? Color.liteAccent.opacity(0.45) : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: isSolid ? [] : [3, 5]))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .animation(.snappy, value: isSolid)
    }
}

private struct ConnectorLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
