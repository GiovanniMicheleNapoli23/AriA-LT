//
//  AriaSetupTourStepLayer.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  Lo strato di un passo: lo spotlight attorno all'elemento, a tutto schermo, e la scheda dalla parte opposta
//  (elemento nella metà alta, scheda in basso). La scheda resta dentro l'area sicura: in alto non va sotto l'ora e
//  la Dynamic Island, in basso non va sotto l'indicatore home. Le coordinate del frame sono globali: si portano nello
//  spazio di ciascuno dei due strati.
//

import SwiftUI

struct AriaSetupTourStepLayer: View {
    let tour: AriaSetupTourViewModel
    let step: AriaSetupTourStep

    var body: some View {
        ZStack {
            // Il velo copre tutto, barra di stato compresa.
            GeometryReader { proxy in
                let screen = proxy.frame(in: .global)
                AriaSetupTourSpotlight(target: visible(in: screen).map { $0.offsetBy(dx: -screen.minX, dy: -screen.minY) },
                                       step: step)
            }
            .ignoresSafeArea()

            // La scheda sta nell'area sicura, dal lato con più spazio libero attorno all'elemento.
            GeometryReader { proxy in
                let area = proxy.frame(in: .global)
                let target = visible(in: area)
                let cardAtTop = target.map { $0.minY - area.minY > area.maxY - $0.maxY } ?? false
                AriaSetupTourStepCard(tour: tour, step: step)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: cardAtTop ? .top : .bottom)
            }
        }
    }

    /// La parte dell'elemento che sta in `bounds`: un elemento più alto dello schermo non porta il riquadro fuori.
    /// `nil` se non c'è frame o l'elemento è tutto fuori.
    private func visible(in bounds: CGRect) -> CGRect? {
        guard let frame = tour.currentFrame else { return nil }
        let clipped = frame.intersection(bounds)
        return clipped.isNull || clipped.isEmpty ? nil : clipped
    }
}
