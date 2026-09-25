//
//  AriaContextItem.swift
//  AriaLite
//
//  Il contesto di una chat: foto e file aggiunti dal "+" del composer, come il
//  context dock della web (use-chat-context-items). Come sulla web è solo stato
//  dell'interfaccia: il backend (/v1/responses) accetta solo testo, quindi niente
//  di questo viaggia ancora con il turno.
//

import Foundation

struct AriaContextItem: Identifiable, Equatable {
    enum Kind: Equatable { case image, document }

    let id = UUID()
    let kind: Kind
    let name: String
    /// Byte del file (documenti).
    var size: Int?
    /// Immagini: anteprima già ridotta, in JPEG.
    var thumbnail: Data?
}
