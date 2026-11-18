//
//  AriaSetupTourSpotlight.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Il velo con il buco attorno all'elemento del passo, l'anello chiaro che lo circonda e l'impulso dell'anello
//  all'arrivo del passo. Il buco non prende i tocchi (la forma pari-dispari è anche la forma dei tocchi): passano
//  all'elemento vero. Fuori dal buco il velo li assorbe. Con "Riduci movimento" niente animazioni né impulso.
//

import SwiftUI

struct AriaSetupTourSpotlight: View {
    /// Il bersaglio nello spazio del velo; `nil` = nessun buco, tutto oscurato.
    let target: CGRect?
    let step: AriaSetupTourStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Quanto il ritaglio esce dall'elemento.
    private let cutoutPadding: CGFloat = 6
    private let cornerRadius: CGFloat = 12

    var body: some View {
        let hole = target?.insetBy(dx: -cutoutPadding, dy: -cutoutPadding)
        let cutout = AriaSetupTourCutout(target: hole ?? .zero, cornerRadius: cornerRadius)

        ZStack {
            cutout
                .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                // Solo fuori dal buco: dentro i tocchi arrivano all'elemento.
                .contentShape(cutout, eoFill: true)
                .onTapGesture {}
                .accessibilityHidden(true)

            if let hole {
                ring(hole)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: hole)
    }

    /// L'anello sottile e chiaro, con l'impulso che parte a ogni passo (si riavvia con l'identità del passo).
    private func ring(_ hole: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
            if !reduceMotion {
                AriaSetupTourPulse(cornerRadius: cornerRadius)
                    .id(step)
            }
        }
        .frame(width: hole.width, height: hole.height)
        .position(x: hole.midX, y: hole.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Un secondo anello che si allarga e svanisce, tre volte, quando compare.
private struct AriaSetupTourPulse: View {
    let cornerRadius: CGFloat
    @State private var spread = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white, lineWidth: 2)
            .scaleEffect(spread ? 1.22 : 1)
            .opacity(spread ? 0 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9).repeatCount(3, autoreverses: false)) { spread = true }
            }
    }
}

/// Il velo con un buco dove sta il bersaglio: due rettangoli con riempimento pari-dispari. Il bersaglio vuoto
/// (`.zero`) non fa il buco, quindi tutto è oscurato.
nonisolated struct AriaSetupTourCutout: Shape {
    var target: CGRect
    var cornerRadius: CGFloat = 12

    var animatableData: CGRect.AnimatableData {
        get { target.animatableData }
        set { target.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if !target.isEmpty {
            path.addRoundedRect(in: target, cornerSize: CGSize(width: cornerRadius, height: cornerRadius), style: .continuous)
        }
        return path
    }
}
