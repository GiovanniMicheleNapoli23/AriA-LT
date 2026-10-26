//
//  AriaPasteboard.swift
//  AriaLite
//
//  Created by Giovanni Michele on 24/10/26.
//
//  "Copia" del testo di Aria (risposte, bozze): sono dati dell'azienda, quindi restano su questo
//  telefono (niente Appunti universali verso Mac e iPad) e spariscono dagli appunti dopo un po'.
//

import UIKit
import UniformTypeIdentifiers

enum AriaPasteboard {
    /// Abbastanza per incollare in un'altra app, non per restare negli appunti tutto il giorno.
    static let lifetime: TimeInterval = 10 * 60

    static func copy(_ text: String) {
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]],
                                      options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(lifetime)])
    }
}
