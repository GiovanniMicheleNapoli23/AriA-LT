//
//  AriaSetupTourOverlay.swift
//  AriaLite
//
//  Created by Giovanni Michele on 13/11/26.
//
//  Il velo del giro guidato: all'intro la scena centrata, poi, per ogni passo, un ritaglio attorno all'elemento
//  indicato (che resta vivo: i tocchi nel ritaglio passano) e la scheda sul lato opposto. Fuori dal ritaglio il
//  velo assorbe ogni tocco. Senza frame dell'elemento (nascosto dai diritti, ancora in caricamento, fuori
//  schermo) si oscura tutto e la scheda compare lo stesso: il passo non blocca mai. Con un foglio aperto dalla
//  sezione il velo non c'è.
//

import SwiftUI

struct AriaSetupTourOverlay: View {
    let tour: AriaSetupTourViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if tour.isVisible, let position = tour.position {
            Group {
                switch position {
                case .intro:
                    AriaSetupTourIntroView(tour: tour)
                case .step(let step):
                    AriaSetupTourStepLayer(tour: tour, step: step)
                }
            }
            .transition(.opacity)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: position)
        }
    }
}
