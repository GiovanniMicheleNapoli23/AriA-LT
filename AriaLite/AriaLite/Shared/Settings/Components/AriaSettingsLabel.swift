//
//  AriaSettingsLabel.swift
//  AriaLite
//
//  Created by Giovanni Michele on 20/11/26.
//
//  Il titolo di una riga delle impostazioni: simbolo e testo nel colore del testo, anche nei bottoni della lista
//  (che altrimenti prendono il colore d'accento).
//

import SwiftUI

struct AriaSettingsLabel: View {
    private let title: Text
    private let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = Text(title)
        self.systemImage = systemImage
    }

    init(text: Text, systemImage: String) {
        self.title = text
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            title
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(.primary)
    }
}
