//
//  AriaGlass.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/09/26.
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
            buttonStyle(AriaMaterialButtonStyle(tint: nil, foreground: .liteAccent))
        }
    }

    /// Pulsante di vetro in evidenza, colorato (`.glassProminent` da iOS 26): sulle versioni precedenti,
    /// un pieno dello stesso colore. `foreground` è il colore della label: `liteOnAccent` sui pieni d'accento,
    /// che in scuro sono chiari.
    @ViewBuilder
    func ariaProminentGlassButtonStyle(tint: Color, foreground: Color = .white) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent).tint(tint).foregroundStyle(foreground)
        } else {
            buttonStyle(AriaMaterialButtonStyle(tint: tint, foreground: foreground))
        }
    }

    /// Il pulsante in evidenza col colore dell'app.
    func ariaAccentGlassButtonStyle() -> some View {
        ariaProminentGlassButtonStyle(tint: .liteAccent, foreground: .liteOnAccent)
    }

    /// Barra flottante in fondo (un pulsante, senza fondo suo): da iOS 26 è una `safeAreaBar`, sotto cui il
    /// contenuto sfuma con un bordo morbido invece di finire contro una striscia piena; prima, un `safeAreaInset`.
    @ViewBuilder
    func ariaBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .bottom, spacing: 0, content: bar)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            safeAreaInset(edge: .bottom, spacing: 0, content: bar)
        }
    }

    /// Barra fissa in alto (un titolo, un logo): resta sempre sopra e il contenuto che scorre le passa sotto,
    /// sfocato. Da iOS 26 è una `safeAreaBar` con il bordo di scroll morbido; prima, un `safeAreaInset` su un
    /// materiale che sfuma verso il basso.
    @ViewBuilder
    func ariaTopBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .top, spacing: 0, content: bar)
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            safeAreaInset(edge: .top, spacing: 0) {
                bar()
                    .background {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                            .ignoresSafeArea(edges: .top)
                            .allowsHitTesting(false)
                    }
            }
        }
    }

    /// Per il morphing tra più forme di vetro nello stesso `AriaGlassEffectContainer` (solo iOS 26: senza
    /// vetro non c'è niente da far scorrere insieme, quindi sulle versioni precedenti non fa nulla).
    @ViewBuilder
    func ariaGlassEffectID(_ id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
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
    var foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if let tint {
                configuration.label
                    .foregroundStyle(foreground)
                    .background(tint, in: Capsule())
            } else {
                configuration.label
                    .foregroundStyle(foreground)
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

    /// Area sicura in fondo vista dal pannello: quella dell'indicatore home se è attaccato al fondo, molto
    /// più alta sopra la tastiera (lì il vetro non può scendere). `nil` finché non è misurata.
    @State private var bottomInset: CGFloat?

    /// Inset dell'indicatore home della finestra (0 sugli schermi squadrati).
    private var homeIndicatorInset: CGFloat {
        let scene = UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
        return scene?.keyWindow?.safeAreaInsets.bottom ?? 0
    }

    /// Con l'indicatore home il vetro scende nell'area sicura fino al margine dal fondo; senza (schermo
    /// squadrato) o con la tastiera aperta non c'è niente sotto e il margine è una semplice spaziatura.
    func body(content: Content) -> some View {
        let home = homeIndicatorInset
        let extends = home > 0 && (bottomInset ?? home) <= home + 1
        content
            .background {
                background(extends: extends)
                    .padding(.bottom, extends ? Self.margin : 0)
                    .ignoresSafeArea(.container, edges: extends ? .bottom : [])
            }
            .padding(.horizontal, Self.margin)
            .padding(.bottom, extends ? 0 : Self.margin)
            // Dopo il padding: il bordo misurato tocca sempre l'area sicura, qualunque sia `extends`.
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
    }

    /// Da iOS 26 gli angoli in basso seguono lo schermo (`ConcentricRectangle`, mai meno di quelli in alto);
    /// prima un raggio fisso vicino a quello dei telefoni con l'indicatore home.
    @ViewBuilder
    private func background(extends: Bool) -> some View {
        if #available(iOS 26.0, *) {
            let shape = ConcentricRectangle(uniformTopCorners: .fixed(Self.topRadius),
                                            uniformBottomCorners: .concentric(minimum: .fixed(Self.topRadius)))
            Color.clear
                .glassEffect(.regular, in: shape)
                .overlay { if let stroke { shape.stroke(stroke, lineWidth: 1) } }
        } else {
            let bottom: CGFloat = extends ? 38 : Self.topRadius
            let shape = UnevenRoundedRectangle(topLeadingRadius: Self.topRadius, bottomLeadingRadius: bottom,
                                               bottomTrailingRadius: bottom, topTrailingRadius: Self.topRadius,
                                               style: .continuous)
            Color.clear
                .ariaGlass(in: shape)
                .overlay { if let stroke { shape.stroke(stroke, lineWidth: 1) } }
        }
    }
}
