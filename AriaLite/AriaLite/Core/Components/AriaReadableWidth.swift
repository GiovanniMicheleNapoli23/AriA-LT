//
//  AriaReadableWidth.swift
//  AriaLite
//
//  Created by Giovanni Michele on 22/10/26.
//
//  Colonna di lettura: su iPad (o in una finestra larga) testi, card e pulsanti non vanno da bordo a bordo.
//  Sotto quella larghezza (ogni iPhone, Split View stretta) non cambia niente.
//

import SwiftUI

enum AriaLayout {
    /// Larghezza massima dei contenuti da leggere: chat, liste di lavori, passi di procedura.
    static let readableWidth: CGFloat = 720
}

extension View {
    /// Limita il contenuto alla colonna di lettura e la centra nello spazio disponibile.
    func ariaReadableWidth(_ maxWidth: CGFloat = AriaLayout.readableWidth,
                           alignment: Alignment = .center) -> some View {
        frame(maxWidth: maxWidth, alignment: alignment)
            .frame(maxWidth: .infinity)
    }
}
