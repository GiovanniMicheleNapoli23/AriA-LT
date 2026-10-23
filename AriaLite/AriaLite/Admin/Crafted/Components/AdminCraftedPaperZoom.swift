//
//  AdminCraftedPaperZoom.swift
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Lo zoom della pagina senza scorrimento laterale: la pagina si impagina alla larghezza disponibile
//  divisa per lo zoom (a 2× va a capo come in una colonna metà più stretta, a 0,5× mostra il doppio per
//  riga) e poi si scala di quanto serve per riempire di nuovo la larghezza. L'altezza si riserva a mano,
//  perché scaleEffect non cambia lo spazio che la vista occupa.
//

import SwiftUI

struct AdminCraftedPaperZoom<Content: View>: View {
    let zoom: Double
    @ViewBuilder var content: Content

    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0

    var body: some View {
        let scale = CGFloat(zoom)
        VStack(alignment: .leading, spacing: 0) {
            // La larghezza disponibile si misura da una vista che non dipende dalla pagina, se no
            // ingrandire la pagina cambierebbe la misura e lo zoom si moltiplicherebbe da solo.
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
            content
                .frame(width: width > 0 ? width / scale : nil)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: width > 0 ? width : nil, height: height * scale, alignment: .topLeading)
                // Finché non si conosce la larghezza la pagina sarebbe impaginata due volte.
                .opacity(width > 0 ? 1 : 0)
        }
    }
}
