//
//  AriaGlass.swift
//  AriaLite
//
//  Liquid Glass dove c'è (iOS 26+), material sulle versioni precedenti (fino a iOS 18).
//

import SwiftUI

extension View {
    /// Vetro sulla forma data: `glassEffect` da iOS 26, altrimenti `.regularMaterial` con un filo di bordo
    /// (il material da solo si confonde con lo sfondo chiaro). `tint` colora entrambe le versioni.
    @ViewBuilder
    func ariaGlass(in shape: some Shape, interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            switch (interactive, tint) {
            case (true, let tint?): glassEffect(.regular.interactive().tint(tint), in: shape)
            case (true, nil): glassEffect(.regular.interactive(), in: shape)
            case (false, let tint?): glassEffect(.regular.tint(tint), in: shape)
            case (false, nil): glassEffect(.regular, in: shape)
            }
        } else {
            background(.regularMaterial, in: shape)
                .background { if let tint { shape.fill(tint) } }
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 3)
        }
    }

    /// Pannello che prende il posto del composer (domanda guidata, procedura): il vetro scende sotto
    /// l'indicatore home e resta staccato dai bordi dello schermo di un piccolo margine, con gli angoli
    /// in basso concentrici a quelli del dispositivo. Il contenuto resta nell'area sicura.
    func ariaBottomPanel(stroke: Color? = nil) -> some View {
        modifier(AriaBottomPanel(stroke: stroke))
    }

    /// Pulsante di vetro non in evidenza (`.glass` da iOS 26): sulle versioni precedenti, lo stesso
    /// material di `ariaGlass` ma applicato come stile del pulsante (segue la forma della label).
    @ViewBuilder
    func ariaGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(AriaMaterialButtonStyle(tint: nil))
        }
    }

    /// Pulsante di vetro in evidenza, colorato (`.glassProminent` da iOS 26): sulle versioni precedenti,
    /// un pieno dello stesso colore.
    @ViewBuilder
    func ariaProminentGlassButtonStyle(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent).tint(tint)
        } else {
            buttonStyle(AriaMaterialButtonStyle(tint: tint))
        }
    }

    /// Per il morphing tra più forme di vetro nello stesso `AriaGlassEffectContainer` (solo iOS 26: senza
    /// vetro non c'è niente da far scorrere insieme, quindi sulle versioni precedenti non fa nulla).
    @ViewBuilder
    func ariaGlassEffectID(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

/// `GlassEffectContainer` da iOS 26 (fa scorrere insieme più forme di vetro quando cambiano);
/// prima di iOS 26 è solo il contenuto, senza quel raggruppamento.
@ViewBuilder
func AriaGlassEffectContainer<Content: View>(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) -> some View {
    if #available(iOS 26.0, *) {
        GlassEffectContainer(spacing: spacing, content: content)
    } else {
        content()
    }
}

/// Il fallback pre-iOS 26 di `.glass` / `.glassProminent`: material (o pieno, se colorato) sulla forma
/// della label, con la stessa attenuazione al tocco.
private struct AriaMaterialButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if let tint {
                configuration.label
                    .foregroundStyle(.white)
                    .background(tint, in: Capsule())
            } else {
                configuration.label
                    .foregroundStyle(Color.liteAccent)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            }
        }
        .opacity(configuration.isPressed ? 0.7 : 1)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Vedi `ariaBottomPanel`.
private struct AriaBottomPanel: ViewModifier {
    var stroke: Color?

    /// Distanza del vetro dai bordi dello schermo (lati e fondo).
    private static let margin: CGFloat = 8
    private static let topRadius: CGFloat = 28

    /// Con l'indicatore home il vetro scende nell'area sicura fino al margine dal fondo; senza (schermo
    /// squadrato) non c'è niente sotto e il margine è una semplice spaziatura.
    private var hasHomeIndicator: Bool {
        let scene = UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
        return (scene?.keyWindow?.safeAreaInsets.bottom ?? 0) > 0
    }

    func body(content: Content) -> some View {
        let extends = hasHomeIndicator
        content
            .background {
                background
                    .padding(.bottom, extends ? Self.margin : 0)
                    .ignoresSafeArea(.container, edges: extends ? .bottom : [])
            }
            .padding(.horizontal, Self.margin)
            .padding(.bottom, extends ? 0 : Self.margin)
    }

    /// Da iOS 26 gli angoli in basso seguono lo schermo (`ConcentricRectangle`, mai meno di quelli in alto);
    /// prima un raggio fisso vicino a quello dei telefoni con l'indicatore home.
    @ViewBuilder
    private var background: some View {
        if #available(iOS 26.0, *) {
            let shape = ConcentricRectangle(uniformTopCorners: .fixed(Self.topRadius),
                                            uniformBottomCorners: .concentric(minimum: .fixed(Self.topRadius)))
            Color.clear
                .glassEffect(.regular, in: shape)
                .overlay { if let stroke { shape.stroke(stroke, lineWidth: 1) } }
        } else {
            let bottom: CGFloat = hasHomeIndicator ? 38 : Self.topRadius
            let shape = UnevenRoundedRectangle(topLeadingRadius: Self.topRadius, bottomLeadingRadius: bottom,
                                               bottomTrailingRadius: bottom, topTrailingRadius: Self.topRadius,
                                               style: .continuous)
            Color.clear
                .ariaGlass(in: shape)
                .overlay { if let stroke { shape.stroke(stroke, lineWidth: 1) } }
        }
    }
}
