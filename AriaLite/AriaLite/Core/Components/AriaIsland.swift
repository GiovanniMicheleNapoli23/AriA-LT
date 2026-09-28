//
//  AriaIsland.swift
//  AriaLite
//
//  Avviso che esce dalla Dynamic Island: una capsula nera che parte esattamente dall'isola, si allarga
//  con il messaggio, resta un attimo e ci rientra. Vive in una finestra sua sopra l'app (anche sopra i
//  fogli, come l'assistente in manutenzione). Sui telefoni senza isola parte da una pillola in cima.
//  Con `actions` chiede una scelta ("Rispondi" / "Non ora"): resta aperta più a lungo e, se nessuno
//  sceglie, rientra come un "Non ora".
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
        /// Pulsanti per accettare o rimandare; senza, è solo un avviso.
        var actions: Actions? = nil
    }

    struct Actions: Equatable {
        let accept: String
        let decline: String
    }

    private(set) var current: Alert?
    /// Capsula aperta (con il messaggio) o raccolta nella forma dell'isola.
    fileprivate(set) var expanded = false
    fileprivate var geometry = Geometry.fallback

    @ObservationIgnored private var window: AriaIslandWindow?
    @ObservationIgnored private var host: AriaIslandHost?
    @ObservationIgnored private var onFinish: ((_ accepted: Bool) -> Void)?
    @ObservationIgnored private var lifecycle: Task<Void, Never>?

    private static let holdTime: Duration = .seconds(2.6)
    /// Con una scelta da fare si lascia il tempo di leggere e decidere.
    private static let choiceHoldTime: Duration = .seconds(8)

    private init() {}

    /// Mostra l'avviso; `onFinish` parte quando la capsula torna nell'isola, con `true` solo se si è
    /// accettato (pulsante o tocco sul testo). Senza una scena attiva non c'è niente da mostrare né
    /// da accettare: `onFinish(false)` parte subito.
    func present(_ alert: Alert, onFinish: @escaping (_ accepted: Bool) -> Void) {
        finish(animated: false)
        guard let scene = Self.activeScene, let host = scene.keyWindow else {
            onFinish(false)
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
            try? await Task.sleep(for: alert.actions == nil ? Self.holdTime : Self.choiceHoldTime)
            guard !Task.isCancelled else { return }
            self.finish(animated: true)
        }
    }

    /// Pulsanti, tocco o scorrimento verso l'alto: si chiude subito.
    func dismiss(accepted: Bool = false) {
        finish(animated: true, accepted: accepted)
    }

    private func finish(animated: Bool, accepted: Bool = false) {
        lifecycle?.cancel()
        lifecycle = nil
        let callback = onFinish
        onFinish = nil
        guard current != nil else { return }
        host?.hidesStatusBar = false
        if animated {
            withAnimation(Self.collapseAnimation) { expanded = false }
            // Il pannello in basso compare mentre la capsula rientra: sembra che il messaggio "scenda".
            callback?(accepted)
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
            callback?(false)
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
            expanded = CGRect(x: (width - openWidth) / 2, y: collapsed.minY, width: openWidth, height: 96)
        }

        /// Altezza della capsula aperta: quella del contenuto, misurato prima di aprirla.
        mutating func fit(height: CGFloat) {
            expanded.size.height = max(collapsed.height + 40, height)
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

    /// Margine di icona, sfera e testo dal bordo della capsula.
    private static let inset: CGFloat = 20
    /// Icona e sfera: stessa misura, così la riga è simmetrica.
    private static let badge: CGFloat = 28
    /// Distanza dal bordo in alto: con il margine laterale le tiene dentro la curva degli angoli (raggio 36).
    private static let badgeTop: CGFloat = 10

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let alert = island.current {
                // Un avviso nuovo è una capsula nuova: così il contenuto si rimisura.
                capsule(alert).id(alert.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func capsule(_ alert: AriaIsland.Alert) -> some View {
        let geometry = island.geometry
        let rect = island.expanded ? geometry.expanded : geometry.collapsed
        let radius = island.expanded ? 36 : rect.height / 2
        return content(alert)
            // Ritaglio ancorato in alto: il contenuto scende dall'isola invece di aprirsi dal centro.
            .frame(width: rect.width, height: rect.height, alignment: .top)
            .background(Color.black, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(island.expanded ? 0.28 : 0), radius: 16, y: 6)
            // Senza isola la pillola di partenza non si confonde con niente: entra ed esce in dissolvenza.
            .opacity(geometry.hasIsland || island.expanded ? 1 : 0)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            // Come una notifica: toccare il testo apre (se c'è da scegliere), scorrere in su rimanda.
            .onTapGesture { island.dismiss(accepted: alert.actions != nil) }
            .gesture(DragGesture(minimumDistance: 8).onEnded { value in
                if value.translation.height < -6 { island.dismiss() }
            })
            .accessibilityElement(children: alert.actions == nil ? .combine : .contain)
            .accessibilityAddTraits(alert.actions == nil ? .isButton : [])
            .accessibilityAction(.escape) { island.dismiss() }
            .padding(.leading, rect.minX)
            .padding(.top, rect.minY)
    }

    /// Come l'isola di sistema aperta: in alto icona e sfera ai lati della fotocamera (al centro non c'è niente,
    /// lì c'è il foro), stessa misura e stesso margine del testo, abbastanza dentro da stare nella curva
    /// degli angoli; titolo e messaggio stanno sotto, allineati all'icona.
    private func content(_ alert: AriaIsland.Alert) -> some View {
        let geometry = island.geometry
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                ZStack {
                    Circle().fill(alert.tint.gradient)
                    Image(systemName: alert.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: Self.badge, height: Self.badge)
                Spacer(minLength: 0)
                AriaOrb(mood: .thinking)
                    .frame(width: Self.badge, height: Self.badge)
            }
            .padding(.horizontal, Self.inset)
            .padding(.top, Self.badgeTop)

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(alert.message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Self.inset)
            .padding(.top, 10)
            .padding(.bottom, alert.actions == nil ? 18 : 14)

            if let actions = alert.actions {
                HStack(spacing: 10) {
                    Button { island.dismiss(accepted: false) } label: {
                        Text(actions.decline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(Color.white.opacity(0.16), in: Capsule())
                    }
                    Button { island.dismiss(accepted: true) } label: {
                        Text(actions.accept)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(alert.tint, in: Capsule())
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        // La riga in alto finisce sotto l'isola: il titolo non va mai dietro la fotocamera.
        .frame(minHeight: geometry.collapsed.height, alignment: .top)
        // Il contenuto ha sempre la larghezza della capsula aperta, così non si ridispone mentre si apre:
        // si allarga il ritaglio e il contenuto appare un po' in ritardo.
        .frame(width: geometry.expanded.width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { island.geometry.fit(height: $0) }
        .opacity(island.expanded ? 1 : 0)
        .blur(radius: island.expanded ? 0 : 8)
        .scaleEffect(island.expanded ? 1 : 0.9, anchor: .top)
        .animation(island.expanded ? AriaIsland.expandAnimation.delay(0.08) : .easeOut(duration: 0.15),
                   value: island.expanded)
    }
}
