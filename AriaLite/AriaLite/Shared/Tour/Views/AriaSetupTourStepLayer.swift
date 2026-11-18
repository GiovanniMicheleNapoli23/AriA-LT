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
                let origin = proxy.frame(in: .global).origin
                AriaSetupTourSpotlight(target: tour.currentFrame.map { $0.offsetBy(dx: -origin.x, dy: -origin.y) },
                                       step: step)
            }
            .ignoresSafeArea()

            // La scheda sta nell'area sicura, sul lato opposto all'elemento.
            GeometryReader { proxy in
                let area = proxy.frame(in: .global)
                let cardAtTop = (tour.currentFrame?.midY ?? 0) > area.midY
                AriaSetupTourStepCard(tour: tour, step: step)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: cardAtTop ? .top : .bottom)
            }
        }
    }
}
