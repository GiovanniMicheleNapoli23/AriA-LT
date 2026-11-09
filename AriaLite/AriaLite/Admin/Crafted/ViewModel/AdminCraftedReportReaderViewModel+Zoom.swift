//
//  AdminCraftedReportReaderViewModel+Zoom.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Lo zoom della pagina del rapporto: i pulsanti più e meno e il pizzico, da 50% a 200%.
//

import Foundation

extension AdminCraftedReportReaderViewModel {
    // MARK: Zoom

    static let defaultZoom = 1.0
    static let zoomRange = 0.5...2.0
    private static let zoomStep = 0.1

    var zoomText: String { "\(Int((zoom * 100).rounded()))%" }
    var canZoomIn: Bool { zoom < Self.zoomRange.upperBound }
    var canZoomOut: Bool { zoom > Self.zoomRange.lowerBound }

    func zoomIn() { nudgeZoom(Self.zoomStep) }
    func zoomOut() { nudgeZoom(-Self.zoomStep) }
    func resetZoom() { zoom = Self.defaultZoom }

    private func nudgeZoom(_ delta: Double) {
        zoom = (min(max(zoom + delta, Self.zoomRange.lowerBound), Self.zoomRange.upperBound) * 10).rounded() / 10
    }

    /// Il pizzico: la magnificazione si applica allo zoom di quando le dita si sono posate.
    func pinchChanged(_ magnification: Double) {
        let base = pinchBase ?? zoom
        pinchBase = base
        zoom = min(max(base * magnification, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    }

    func pinchEnded() {
        pinchBase = nil
        zoom = (zoom * 100).rounded() / 100
    }
}
