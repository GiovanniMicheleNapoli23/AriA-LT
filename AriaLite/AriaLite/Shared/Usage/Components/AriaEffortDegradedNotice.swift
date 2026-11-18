//
//  AriaEffortDegradedNotice.swift
//  AriaLite
//
//  Created by Giovanni Michele on 18/11/26.
//
//  L'avviso sotto una risposta che ha girato a un livello più leggero di quello chiesto: una riga di testo
//  piccolo con l'icona "info", in grigio (non è un errore). La frase la compone AriaEffortNotice.
//

import SwiftUI

struct AriaEffortDegradedNotice: View {
    let text: String

    var body: some View {
        Label {
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chat.effortNotice")
    }
}
