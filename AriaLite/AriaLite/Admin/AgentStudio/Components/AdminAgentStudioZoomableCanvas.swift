//
//  AdminAgentStudioZoomableCanvas.swift
//  AriaLite
//
//  Created by Giovanni Michele on 26/10/26.
//
//  Scorrimento e zoom a due dita del canvas: una UIScrollView che ingrandisce una vista SwiftUI (nodi e archi).
//  "Adatta" porta tutto il grafo a schermo; il contenuto più piccolo dello schermo resta centrato.
//

import SwiftUI
import UIKit

/// Un comando della barra: ogni invio ha un numero nuovo, così il contenitore reagisce anche a due "Adatta" di fila.
struct AdminAgentStudioCanvasCommand: Equatable {
    enum Kind: Equatable { case fit, zoomIn, zoomOut }

    private(set) var kind: Kind = .fit
    private(set) var serial = 0

    mutating func send(_ kind: Kind) {
        self.kind = kind
        serial += 1
    }
}

struct AdminAgentStudioZoomableCanvas<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    let command: AdminAgentStudioCanvasCommand
    private let content: Content

    init(contentSize: CGSize, command: AdminAgentStudioCanvasCommand, @ViewBuilder content: () -> Content) {
        self.contentSize = contentSize
        self.command = command
        self.content = content()
    }

    func makeCoordinator() -> Coordinator { Coordinator(contentSize: contentSize) }

    func makeUIView(context: Context) -> AdminAgentStudioCanvasScrollView {
        let coordinator = context.coordinator
        let scrollView = AdminAgentStudioCanvasScrollView()
        scrollView.delegate = coordinator
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.minimumZoomScale = Coordinator.lowestZoom
        scrollView.maximumZoomScale = Coordinator.highestZoom
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        scrollView.contentSize = contentSize

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.safeAreaRegions = []
        let container = UIView(frame: CGRect(origin: .zero, size: contentSize))
        container.addSubview(hosting.view)
        hosting.view.frame = container.bounds
        scrollView.addSubview(container)

        coordinator.hosting = hosting
        coordinator.container = container
        scrollView.onLayout = { [weak coordinator, weak scrollView] in
            guard let coordinator, let scrollView else { return }
            coordinator.layoutChanged(in: scrollView)
        }
        return scrollView
    }

    func updateUIView(_ scrollView: AdminAgentStudioCanvasScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.hosting?.rootView = content
        coordinator.update(contentSize: contentSize, command: command, in: scrollView)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UIScrollViewDelegate {
        static var lowestZoom: CGFloat { 0.25 }
        static var highestZoom: CGFloat { 2.5 }

        var hosting: UIHostingController<Content>?
        var container: UIView?

        private var contentSize: CGSize
        private var lastSerial = 0
        /// Finché la persona non scorre né zooma, il grafo resta adattato allo schermo (anche se i nodi si misurano dopo).
        private var userAdjusted = false
        private var lastLayoutBounds = CGRect.zero
        private var lastSafeInsets = UIEdgeInsets.zero

        init(contentSize: CGSize) {
            self.contentSize = contentSize
        }

        // MARK: Delegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { container }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            scrollView.contentInset = insets(for: scrollView, zoom: scrollView.zoomScale)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { userAdjusted = true }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) { userAdjusted = true }

        // MARK: Aggiornamenti dalla vista

        func update(contentSize newSize: CGSize, command: AdminAgentStudioCanvasCommand, in scrollView: UIScrollView) {
            if newSize != contentSize { resize(to: newSize, in: scrollView) }
            guard command.serial != lastSerial else { return }
            lastSerial = command.serial
            switch command.kind {
            case .fit:
                userAdjusted = false
                fit(in: scrollView, animated: true)
            case .zoomIn:
                userAdjusted = true
                scrollView.setZoomScale(min(scrollView.maximumZoomScale, scrollView.zoomScale * 1.35), animated: true)
            case .zoomOut:
                userAdjusted = true
                scrollView.setZoomScale(max(scrollView.minimumZoomScale, scrollView.zoomScale / 1.35), animated: true)
            }
        }

        /// Chiamato a ogni layout della scroll view; agisce solo se cambiano dimensioni o margini di sicurezza.
        func layoutChanged(in scrollView: UIScrollView) {
            let bounds = CGRect(origin: .zero, size: scrollView.bounds.size)
            let safe = scrollView.safeAreaInsets
            guard bounds != lastLayoutBounds || safe != lastSafeInsets else { return }
            lastLayoutBounds = bounds
            lastSafeInsets = safe
            guard bounds.width > 0, bounds.height > 0 else { return }
            updateZoomLimits(in: scrollView)
            if userAdjusted {
                scrollView.contentInset = insets(for: scrollView, zoom: scrollView.zoomScale)
            } else {
                fit(in: scrollView, animated: false)
            }
        }

        // MARK: Misure

        /// Il contenuto cambia misura (i nodi si misurano, il Dynamic Type cambia): si ridimensiona lo zoomato
        /// riportando lo zoom a 1 solo il tempo di cambiare la cornice.
        private func resize(to size: CGSize, in scrollView: UIScrollView) {
            contentSize = size
            guard let container, let hosting else { return }
            let zoom = scrollView.zoomScale
            let offset = scrollView.contentOffset
            scrollView.zoomScale = 1
            container.frame = CGRect(origin: .zero, size: size)
            hosting.view.frame = container.bounds
            scrollView.contentSize = size
            if zoom != 1 { scrollView.zoomScale = zoom }
            updateZoomLimits(in: scrollView)
            if userAdjusted {
                scrollView.contentOffset = offset
                scrollView.contentInset = insets(for: scrollView, zoom: scrollView.zoomScale)
            } else {
                fit(in: scrollView, animated: false)
            }
        }

        /// L'area dello schermo non coperta da barre e home indicator.
        private func availableSize(of scrollView: UIScrollView) -> CGSize {
            let safe = scrollView.safeAreaInsets
            return CGSize(width: scrollView.bounds.width - safe.left - safe.right,
                          height: scrollView.bounds.height - safe.top - safe.bottom)
        }

        /// Lo zoom con cui il grafo entra tutto nell'area disponibile (al massimo 1).
        private func fitScale(in scrollView: UIScrollView) -> CGFloat? {
            let available = availableSize(of: scrollView)
            guard available.width > 0, available.height > 0, contentSize.width > 0, contentSize.height > 0 else { return nil }
            let padding: CGFloat = 16
            let horizontal = (available.width - padding * 2) / contentSize.width
            let vertical = (available.height - padding * 2) / contentSize.height
            return max(0.01, min(1, horizontal, vertical))
        }

        /// Lo zoom minimo lascia sempre raggiungere "Adatta", anche per un grafo molto grande.
        private func updateZoomLimits(in scrollView: UIScrollView) {
            scrollView.minimumZoomScale = min(Self.lowestZoom, fitScale(in: scrollView) ?? Self.lowestZoom)
            scrollView.maximumZoomScale = Self.highestZoom
        }

        /// I margini che tengono al centro il contenuto più piccolo dell'area disponibile.
        private func insets(for scrollView: UIScrollView, zoom: CGFloat) -> UIEdgeInsets {
            let safe = scrollView.safeAreaInsets
            let available = availableSize(of: scrollView)
            let extraX = max(0, (available.width - contentSize.width * zoom) / 2)
            let extraY = max(0, (available.height - contentSize.height * zoom) / 2)
            return UIEdgeInsets(top: safe.top + extraY, left: safe.left + extraX,
                                bottom: safe.bottom + extraY, right: safe.right + extraX)
        }

        private func fit(in scrollView: UIScrollView, animated: Bool) {
            updateZoomLimits(in: scrollView)
            guard let scale = fitScale(in: scrollView) else { return }
            let target = max(scrollView.minimumZoomScale, scale)
            let apply = {
                scrollView.zoomScale = target
                let inset = self.insets(for: scrollView, zoom: target)
                scrollView.contentInset = inset
                scrollView.contentOffset = CGPoint(x: -inset.left, y: -inset.top)
            }
            if animated {
                UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: apply)
            } else {
                apply()
            }
        }
    }
}

/// Una UIScrollView che avvisa a ogni layout, per rimettere al centro il contenuto quando cambiano le dimensioni.
final class AdminAgentStudioCanvasScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
