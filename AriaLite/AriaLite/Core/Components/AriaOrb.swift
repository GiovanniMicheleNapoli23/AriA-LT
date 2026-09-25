//
//  AriaOrb.swift
//  AriaLite
//
//  La sfera di Aria, animata dallo shader AriaOrb.metal. Due stati come nell'HTML
//  di riferimento (new-blob-v0.3-b_w.html): `idle`, lenta, e `thinking`, veloce e con
//  l'alone, per quando Aria sta rispondendo. Il passaggio tra i due è interpolato
//  (colori nello spazio lineare) e il movimento non salta quando cambia la velocità.
//

import SwiftUI

struct AriaOrb: View {
    enum Mood { case idle, thinking }

    var mood: Mood = .idle
    /// Ferma l'animazione (es. gli avatar dei messaggi vecchi): resta l'ultimo fotogramma.
    var isAnimating = true
    /// Raggio della sfera rispetto al riquadro (1 = tocca i bordi). Più piccolo lascia spazio all'alone.
    var radius: Float = 0.86
    /// Punto del movimento da cui partire (secondi a velocità 1): per un'immagine ferma o per sfasare più sfere.
    var startPhase: Double = AriaOrb.restingPhase

    /// La posa della GIF di riferimento: parte alta chiara con il riflesso rosa, parte bassa scura.
    static let restingPhase: Double = 2.4

    @State private var engine: AriaOrbEngine

    init(mood: Mood = .idle, isAnimating: Bool = true, radius: Float = 0.86, startPhase: Double = AriaOrb.restingPhase) {
        self.mood = mood
        self.isAnimating = isAnimating
        self.radius = radius
        self.startPhase = startPhase
        _engine = State(initialValue: AriaOrbEngine(phase: startPhase))
    }

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { timeline in
            let values = engine.values(at: timeline.date, mood: mood, radius: radius)
            Rectangle()
                .visualEffect { content, proxy in
                    content.colorEffect(ShaderLibrary.ariaOrb(.float2(proxy.size), .floatArray(values)))
                }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// La sfera che passa da una posizione all'altra (chat vuota → sotto la risposta) con `matchedGeometryEffect`.
    @ViewBuilder
    func ariaOrbHero(_ namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedGeometryEffect(id: "aria.orb", in: namespace)
        } else {
            self
        }
    }
}

/// Stato dell'animazione: non è osservato, lo avanza il TimelineView a ogni fotogramma.
private final class AriaOrbEngine {
    private var mood: AriaOrb.Mood?
    private var from = AriaOrbEngine.idle
    private var target = AriaOrbEngine.idle
    private var displayed = AriaOrbEngine.idle
    private var transitionStart = Date.distantPast
    private var duration: TimeInterval = 0
    private var lastFrame: Date?
    private var phase: Double

    init(phase: Double) { self.phase = phase }

    private func transition(to next: AriaOrb.Mood, at date: Date) {
        guard next != mood else { return }
        let first = mood == nil
        mood = next
        let seed = next == .thinking ? Self.thinking : Self.idle
        if first {
            from = seed
            target = seed
            displayed = seed
            duration = 0
            return
        }
        from = displayed
        target = seed
        transitionStart = date
        // Come l'HTML: si accende in fretta, si calma piano.
        duration = next == .thinking ? 0.2 : 0.7
    }

    /// Il fotogramma a `date`. Lo stato si legge qui e non in un `onChange`, così vale anche
    /// per il primo fotogramma e per ImageRenderer.
    func values(at date: Date, mood: AriaOrb.Mood, radius: Float) -> [Float] {
        transition(to: mood, at: date)
        let progress = progress(at: date)
        for i in 3..<displayed.count {
            let isColor = i >= 40 && (i - 40) % 4 < 3
            displayed[i] = isColor ? Self.mixSRGB(from[i], target[i], progress)
                                   : from[i] + (target[i] - from[i]) * progress
        }
        // La fase avanza con la velocità corrente: cambiare velocità non fa saltare il fluido.
        let speed = Double(max(displayed[3], 0))
        if let lastFrame { phase += min(0.1, max(0, date.timeIntervalSince(lastFrame))) * speed }
        lastFrame = date
        var out = displayed
        out[2] = Float(phase / max(speed, 0.001))
        out[4] = radius
        return out
    }

    private func progress(at date: Date) -> Float {
        guard duration > 0 else { return 1 }
        let raw = Float(min(1, max(0, date.timeIntervalSince(transitionStart) / duration)))
        return mood == .thinking ? 1 - pow(1 - raw, 3) : raw * raw * (3 - 2 * raw)
    }

    private static func mixSRGB(_ a: Float, _ b: Float, _ t: Float) -> Float {
        func toLinear(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        func toSRGB(_ v: Float) -> Float { v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055 }
        return toSRGB(toLinear(a) + (toLinear(b) - toLinear(a)) * t)
    }

    // I parametri dell'HTML (stateSeeds), stesso ordine della struct Uniforms: 40 scalari, poi 12 colori RGBA.
    // size/time/radius vengono sovrascritti a ogni fotogramma.
    static let idle: [Float] = [
        1, 1, 0, 0.266, 0.7, 0.33, 1.196, 0.1932,
        2.2, 0.08, 0, 0, 0.66, 0.32, 0.837, 19,
        0.005, 0, 0, 1, 0.76, 0.03, 2, 0.42,
        0.77, 0.23, 65, 0, 0, 1, 0.22, 0.25,
        0.72, 5, 0.42, 1.25, 0.55, 0.3, 1.2, 0.7,
        0.0392157, 0.0392157, 0.0470588, 1, 0.933333, 0.764706, 0.929412, 1,
        0.921569, 0.921569, 0.894118, 1, 0.921569, 0.921569, 0.894118, 1,
        0.709804, 0.541176, 0.647059, 1, 1, 1, 1, 1,
        0.894118, 0.545098, 1, 1, 0.701961, 0.211765, 0.988235, 1,
        1, 0.945098, 0.980392, 1, 0.905882, 0.85098, 1, 1,
        0.0392157, 0.0392157, 0.0470588, 1, 0.423529, 0.243137, 0.447059, 1,
    ]

    static let thinking: [Float] = [
        1, 1, 0, 2.44, 0.7, 0.39, 3.3, 0.73,
        2.2, 0.15, 0, 0, 0.66, 0.32, 1.32, 19,
        0.005, 0.42, 0, 1, 0.76, 0.1, 2, 0.42,
        0.77, 0.23, 65, 0, 0, 1, 0.22, 0.25,
        0.72, 5, 0.42, 1.25, 0.55, 0.3, 1.2, 0.7,
        0.0392157, 0.0392157, 0.0470588, 1, 0.933333, 0.764706, 0.929412, 1,
        0.921569, 0.921569, 0.894118, 1, 0.921569, 0.921569, 0.894118, 1,
        1, 0.85098, 0.941176, 1, 1, 1, 1, 1,
        0.894118, 0.545098, 1, 1, 0.701961, 0.211765, 0.988235, 1,
        1, 0.945098, 0.980392, 1, 0.905882, 0.85098, 1, 1,
        0.0392157, 0.0392157, 0.0470588, 1, 1, 1, 1, 1,
    ]
}

#Preview {
    VStack(spacing: 30) {
        AriaOrb(radius: 0.7).frame(width: 200, height: 200)
        AriaOrb(mood: .thinking, radius: 0.7).frame(width: 200, height: 200)
        HStack { AriaOrb().frame(width: 28, height: 28); AriaOrb().frame(width: 20, height: 20) }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
