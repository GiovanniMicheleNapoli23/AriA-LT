//
//  Colors.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/03/26.
//
//  I colori dell'app, chiari e scuri: seguono l'aspetto del sistema. In scuro il navy del logo sparirebbe
//  sul nero, quindi l'accento diventa un bianco appena lilla; sopra i pieni d'accento il testo passa da
//  bianco a nero (`liteOnAccent`).
//

import SwiftUI
import UIKit

extension Color {
    // MARK: - Brand Colors (Aria — nuovo logo navy)
    static let liteBackground = Color(light: (0.98, 0.98, 0.99), dark: (0, 0, 0))  // bianco quasi puro / nero
    static let liteAccent = Color(light: (0.08, 0.14, 0.25), dark: (0.93, 0.91, 0.98))  // #141F3F navy del logo / bianco lilla
    /// Testo e icone sopra un pieno d'accento: bianco sul navy, nero sul bianco lilla.
    static let liteOnAccent = Color(light: (1, 1, 1), dark: (0, 0, 0))
    static let liteSurface = Color(light: (1.00, 1.00, 1.00), dark: (0.11, 0.11, 0.12))  // bianco puro / il pannello in scuro
    static let liteBorder = Color(light: (0.08, 0.14, 0.25, 0.12), dark: (1.00, 1.00, 1.00, 0.12))
    static let liteText = Color(light: (0.08, 0.14, 0.25), dark: (0.95, 0.94, 0.98))  // stesso navy / bianco lilla
    static let liteSidebar = Color(light: (0.95, 0.955, 0.965), dark: (0, 0, 0))  // un filo staccata dal pannello / nero
    /// Il velo sul pannello mentre la sidebar si apre: in chiaro il bianco di prima, in scuro un grigio
    /// (il pannello, nero da chiuso, diventa grigio mentre la sidebar, nera, si scopre).
    static let litePanelVeil = Color(light: (1.00, 1.00, 1.00), dark: (0.36, 0.36, 0.38))
    /// Le azioni a scorrimento hanno sempre la label bianca: in scuro un lilla spento invece del bianco lilla.
    static let liteSwipeAccent = Color(light: (0.08, 0.14, 0.25), dark: (0.36, 0.34, 0.47))
    /// Il filo chiaro sul bordo delle schede sul vetro: in scuro più tenue, se no si accende.
    static let liteGlassEdge = Color(light: (1, 1, 1, 0.35), dark: (1, 1, 1, 0.12))

    // MARK: - Toni spenti (esiti, tendenze): verde salvia, ambra e corallo invece dei colori pieni di sistema
    static let liteSuccess = Color(light: (0.22, 0.52, 0.38), dark: (0.50, 0.76, 0.60))
    static let liteWarning = Color(light: (0.72, 0.47, 0.16), dark: (0.90, 0.70, 0.42))
    static let liteDanger = Color(light: (0.72, 0.31, 0.29), dark: (0.89, 0.54, 0.50))
}

private extension Color {
    typealias RGB = (red: CGFloat, green: CGFloat, blue: CGFloat)
    typealias RGBA = (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)

    init(light: RGB, dark: RGB) {
        self.init(light: (light.red, light.green, light.blue, 1), dark: (dark.red, dark.green, dark.blue, 1))
    }

    /// Un colore che cambia con l'aspetto (chiaro/scuro) della vista che lo disegna.
    init(light: RGBA, dark: RGBA) {
        self.init(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
        })
    }
}
