//
//  AriaIsland.swift
//  AriaLite
//
//  Avviso che esce dalla Dynamic Island: una capsula nera che parte esattamente dall'isola, si allarga
//  con il messaggio, resta un attimo e ci rientra. Vive in una finestra sua sopra l'app (anche sopra i
//  fogli, come l'assistente in manutenzione). Sui telefoni senza isola parte da una pillola in cima.
//
//  Le Live Activity non servono qui: con l'app in primo piano l'isola di sistema non le mostra.
//

import SwiftUI
import UIKit

@Observable
final class AriaIsland {
    static let shared = AriaIsland()

    struct Alert: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let systemImage: String
        let tint: Color
    }

    private(set) var current: Alert?
    /// Capsula aperta (con il messaggio) o raccolta nella forma dell'isola.
    fileprivate(set) var expanded = false
    fileprivate var geometry = Geometry.fallback

    @ObservationIgnored private var window: AriaIslandWindow?
    @ObservationIgnored private var host: AriaIslandHost?
    @ObservationIgnored private var onFinish: (() -> Void)?
    @ObservationIgnored private var lifecycle: Task<Void, Never>?

    private static let holdTime: Duration = .seconds(2.6)

    private init() {}

    /// Mostra l'avviso; `onFinish` parte quando la capsula torna nell'isola (da sola o con un tocco).
    /// Senza una scena attiva non c'è niente da animare: `onFinish` parte subito.
    func present(_ alert: Alert, onFinish: @escaping () -> Void) {
        finish(animated: false)
        guard let scene = Self.activeScene, let host = scene.keyWindow else {
            onFinish()
            return
        }
        geometry = Geometry(window: host)
        install(in: scene)
        current = alert
        expanded = false
        self.onFinish = onFinish
        UIAccessibility.post(notification: .announcement, argument: "\(alert.title). \(alert.message)")

        lifecycle = Task { [weak self] in
            // Un giro di layout con la capsula chiusa, poi si apre: così l'animazione parte dall'isola.
            try? await Task.sleep(for: .milliseconds(40))
            guard let self, !Task.isCancelled else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.9)
            withAnimation(Self.expandAnimation) { self.expanded = true }
            self.host?.hidesStatusBar = true
            try? await Task.sleep(for: Self.holdTime)
            guard !Task.isCancelled else { return }
            self.finish(animated: true)
        }
    }

    /// Tocco o scorrimento verso l'alto: si chiude subito.
    func dismiss() {
        finish(animated: true)
    }

    private func finish(animated: Bool) {
        lifecycle?.cancel()
        lifecycle = nil
        let callback = onFinish
        onFinish = nil
        guard current != nil else { return }
        host?.hidesStatusBar = false
        if animated {
            withAnimation(Self.collapseAnimation) { expanded = false }
            // Il pannello in basso compare mentre la capsula rientra: sembra che il messaggio "scenda".
            callback?()
            let shown = current?.id
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard let self, self.current?.id == shown else { return }
                self.current = nil
                self.window?.isHidden = true
            }
        } else {
            expanded = false
            current = nil
            window?.isHidden = true
            callback?()
        }
    }

    private static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    fileprivate static var expandAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.74)
    }
    fileprivate static var collapseAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86)
    }

    // MARK: Finestra

    private static var activeScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// A tutto schermo (solo così può nascondere la status bar, come fa l'isola di sistema quando si apre),
    /// ma i tocchi fuori dalla capsula arrivano all'app come sempre.
    private func install(in scene: UIWindowScene) {
        if let window, window.windowScene === scene {
            window.isHidden = false
            return
        }
        let window = AriaIslandWindow(windowScene: scene)
        window.windowLevel = .statusBar + 1
        window.backgroundColor = .clear
        window.touchableRect = { [weak self] in
            guard let self, self.current != nil else { return nil }
            return self.expanded ? self.geometry.expanded : self.geometry.collapsed
        }
        let host = AriaIslandHost(rootView: AriaIslandView(island: self))
        host.view.backgroundColor = .clear
        // La capsula sta proprio nell'area sicura in alto: si posiziona in punti dello schermo, senza margini.
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        self.host = host
    }

    // MARK: Geometria

    /// Dove sta l'isola e quanto si apre la capsula, in punti dello schermo.
    fileprivate struct Geometry {
        var screenWidth: CGFloat
        var hasIsland: Bool
        var collapsed: CGRect
        var expanded: CGRect

        static let fallback = Geometry(width: 393, safeTop: 59)

        @MainActor
        init(window: UIWindow) {
            self.init(width: window.bounds.width, safeTop: window.safeAreaInsets.top)
        }

        init(width: CGFloat, safeTop: CGFloat) {
            screenWidth = width
            // Con la Dynamic Island l'area sicura in alto è di 59–62 pt; con il notch 44–50.
            hasIsland = safeTop >= 51 && width < 500
            let island = CGSize(width: 126, height: 37.33)
            if hasIsland {
                // L'isola sta ~48 pt sopra il bordo dell'area sicura (11 pt dall'alto su 14/15 Pro, 14 sui 16 Pro).
                let top = max(11, safeTop - 48)
                collapsed = CGRect(x: (width - island.width) / 2, y: top, width: island.width, height: island.height)
            } else {
                let top = max(6, safeTop - 38)
                collapsed = CGRect(x: (width - 96) / 2, y: top, width: 96, height: 30)
            }
            let openWidth = min(width - 20, 420)
            expanded = CGRect(x: (width - openWidth) / 2, y: collapsed.minY, width: openWidth, height: 82)
        }
    }
}

/// Lascia passare all'app i tocchi fuori dalla capsula.
private final class AriaIslandWindow: UIWindow {
    var touchableRect: () -> CGRect? = { nil }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let rect = touchableRect() else { return false }
        return rect.insetBy(dx: -4, dy: -4).contains(point)
    }
}

private final class AriaIslandHost: UIHostingController<AriaIslandView> {
    var hidesStatusBar = false {
        didSet {
            guard hidesStatusBar != oldValue else { return }
            UIView.animate(withDuration: 0.25) { self.setNeedsStatusBarAppearanceUpdate() }
        }
    }

    override var prefersStatusBarHidden: Bool { hidesStatusBar }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
}

// MARK: - Vista

private struct AriaIslandView: View {
    let island: AriaIsland

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let alert = island.current {
                capsule(alert)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func capsule(_ alert: AriaIsland.Alert) -> some View {
        let geometry = island.geometry
        let rect = island.expanded ? geometry.expanded : geometry.collapsed
        let radius = island.expanded ? 36 : rect.height / 2
        return content(alert)
            .frame(width: rect.width, height: rect.height)
            .background(Color.black, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(island.expanded ? 0.28 : 0), radius: 16, y: 6)
            // Senza isola la pillola di partenza non si confonde con niente: entra ed esce in dissolvenza.
            .opacity(geometry.hasIsland || island.expanded ? 1 : 0)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onTapGesture { island.dismiss() }
            .gesture(DragGesture(minimumDistance: 8).onEnded { value in
                if value.translation.height < -6 { island.dismiss() }
            })
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { island.dismiss() }
            .padding(.leading, rect.minX)
            .padding(.top, rect.minY)
    }

    private func content(_ alert: AriaIsland.Alert) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(alert.tint.gradient)
                Image(systemName: alert.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(alert.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)

            AriaOrb(mood: .thinking)
                .frame(width: 26, height: 26)
        }
        .padding(.horizontal, 18)
        // Il contenuto ha sempre la misura della capsula aperta (centrato e ritagliato dalla capsula), così non
        // si ridispone mentre si apre: si allarga il ritaglio e il contenuto appare un po' in ritardo.
        .frame(width: island.geometry.expanded.width, height: island.geometry.expanded.height)
        .opacity(island.expanded ? 1 : 0)
        .blur(radius: island.expanded ? 0 : 8)
        .scaleEffect(island.expanded ? 1 : 0.85)
        .animation(island.expanded ? AriaIsland.expandAnimation.delay(0.08) : .easeOut(duration: 0.15),
                   value: island.expanded)
    }
}
